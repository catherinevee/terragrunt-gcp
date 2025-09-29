package terraform

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// StateCache provides caching functionality for Terraform state
type StateCache struct {
	mu            sync.RWMutex
	cacheDir      string
	entries       map[string]*CacheEntry
	maxSize       int64
	currentSize   int64
	ttl           time.Duration
	cleanupTicker *time.Ticker
	stopCleanup   chan bool
}

// CacheEntry represents a single cache entry
type CacheEntry struct {
	Key          string
	Path         string
	Size         int64
	Hash         string
	CreatedAt    time.Time
	LastAccessed time.Time
	TTL          time.Duration
	Metadata     map[string]interface{}
	State        *State
}

// State represents Terraform state structure
type State struct {
	Version          int                    `json:"version"`
	TerraformVersion string                 `json:"terraform_version"`
	Serial           int64                  `json:"serial"`
	Lineage          string                 `json:"lineage"`
	Outputs          map[string]StateOutput `json:"outputs"`
	Resources        []StateResource        `json:"resources"`
	CheckResults     []CheckResult          `json:"check_results"`
}

// StateOutput represents an output value in state
type StateOutput struct {
	Value     interface{} `json:"value"`
	Type      interface{} `json:"type"`
	Sensitive bool        `json:"sensitive,omitempty"`
}

// CheckResult represents a check result in state
type CheckResult struct {
	ObjectKind   string `json:"object_kind"`
	ConfigAddr   string `json:"config_addr"`
	Status       string `json:"status"`
	FailureMessages []string `json:"failure_messages,omitempty"`
}

// CacheOptions represents options for creating a state cache
type CacheOptions struct {
	CacheDir      string
	MaxSize       int64
	TTL           time.Duration
	CleanupPeriod time.Duration
}

// NewStateCache creates a new state cache instance
func NewStateCache(opts ...func(*CacheOptions)) *StateCache {
	options := &CacheOptions{
		CacheDir:      filepath.Join(os.TempDir(), "terraform-cache"),
		MaxSize:       1024 * 1024 * 1024, // 1GB default
		TTL:           1 * time.Hour,
		CleanupPeriod: 15 * time.Minute,
	}

	for _, opt := range opts {
		opt(options)
	}

	cache := &StateCache{
		cacheDir:    options.CacheDir,
		entries:     make(map[string]*CacheEntry),
		maxSize:     options.MaxSize,
		ttl:         options.TTL,
		stopCleanup: make(chan bool),
	}

	// Create cache directory
	os.MkdirAll(cache.cacheDir, 0755)

	// Start cleanup routine
	cache.startCleanup(options.CleanupPeriod)

	return cache
}

// WithCacheDir sets the cache directory
func WithCacheDir(dir string) func(*CacheOptions) {
	return func(o *CacheOptions) {
		o.CacheDir = dir
	}
}

// WithMaxSize sets the maximum cache size
func WithMaxSize(size int64) func(*CacheOptions) {
	return func(o *CacheOptions) {
		o.MaxSize = size
	}
}

// WithTTL sets the cache TTL
func WithTTL(ttl time.Duration) func(*CacheOptions) {
	return func(o *CacheOptions) {
		o.TTL = ttl
	}
}

// WithCleanupPeriod sets the cleanup period
func WithCleanupPeriod(period time.Duration) func(*CacheOptions) {
	return func(o *CacheOptions) {
		o.CleanupPeriod = period
	}
}

// Get retrieves state from cache
func (c *StateCache) Get(ctx context.Context, key string) (*State, error) {
	c.mu.RLock()
	entry, exists := c.entries[key]
	c.mu.RUnlock()

	if !exists {
		return nil, fmt.Errorf("cache miss: key %s not found", key)
	}

	// Check if entry has expired
	if time.Since(entry.CreatedAt) > entry.TTL {
		c.Delete(ctx, key)
		return nil, fmt.Errorf("cache expired: key %s", key)
	}

	// Update last accessed time
	c.mu.Lock()
	entry.LastAccessed = time.Now()
	c.mu.Unlock()

	// Load state from file if not in memory
	if entry.State == nil {
		state, err := c.loadStateFromFile(entry.Path)
		if err != nil {
			return nil, err
		}
		entry.State = state
	}

	return entry.State, nil
}

// Put stores state in cache
func (c *StateCache) Put(ctx context.Context, key string, state *State, metadata map[string]interface{}) error {
	// Calculate state size
	data, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("marshaling state: %w", err)
	}

	size := int64(len(data))

	// Check if we need to evict entries
	if err := c.ensureSpace(size); err != nil {
		return err
	}

	// Calculate hash
	hash := c.calculateHash(data)

	// Generate file path
	filename := fmt.Sprintf("%s_%s.tfstate", key, hash[:8])
	path := filepath.Join(c.cacheDir, filename)

	// Write state to file
	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("writing cache file: %w", err)
	}

	// Create cache entry
	entry := &CacheEntry{
		Key:          key,
		Path:         path,
		Size:         size,
		Hash:         hash,
		CreatedAt:    time.Now(),
		LastAccessed: time.Now(),
		TTL:          c.ttl,
		Metadata:     metadata,
		State:        state,
	}

	// Store entry
	c.mu.Lock()
	if oldEntry, exists := c.entries[key]; exists {
		c.currentSize -= oldEntry.Size
		if oldEntry.Path != path {
			os.Remove(oldEntry.Path)
		}
	}
	c.entries[key] = entry
	c.currentSize += size
	c.mu.Unlock()

	return nil
}

// Delete removes an entry from cache
func (c *StateCache) Delete(ctx context.Context, key string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	entry, exists := c.entries[key]
	if !exists {
		return fmt.Errorf("key %s not found", key)
	}

	// Remove file
	if err := os.Remove(entry.Path); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("removing cache file: %w", err)
	}

	// Update size and remove entry
	c.currentSize -= entry.Size
	delete(c.entries, key)

	return nil
}

// Clear removes all entries from cache
func (c *StateCache) Clear(ctx context.Context) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Remove all files
	for _, entry := range c.entries {
		os.Remove(entry.Path)
	}

	// Clear entries
	c.entries = make(map[string]*CacheEntry)
	c.currentSize = 0

	return nil
}

// Has checks if a key exists in cache
func (c *StateCache) Has(key string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	entry, exists := c.entries[key]
	if !exists {
		return false
	}

	// Check if expired
	if time.Since(entry.CreatedAt) > entry.TTL {
		return false
	}

	return true
}

// GetMetadata retrieves metadata for a cache entry
func (c *StateCache) GetMetadata(key string) (map[string]interface{}, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	entry, exists := c.entries[key]
	if !exists {
		return nil, fmt.Errorf("key %s not found", key)
	}

	return entry.Metadata, nil
}

// SetMetadata updates metadata for a cache entry
func (c *StateCache) SetMetadata(key string, metadata map[string]interface{}) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	entry, exists := c.entries[key]
	if !exists {
		return fmt.Errorf("key %s not found", key)
	}

	entry.Metadata = metadata
	return nil
}

// GetStats returns cache statistics
func (c *StateCache) GetStats() CacheStats {
	c.mu.RLock()
	defer c.mu.RUnlock()

	stats := CacheStats{
		EntryCount:  len(c.entries),
		CurrentSize: c.currentSize,
		MaxSize:     c.maxSize,
		HitCount:    0,
		MissCount:   0,
		Entries:     make([]CacheEntryStats, 0, len(c.entries)),
	}

	for _, entry := range c.entries {
		stats.Entries = append(stats.Entries, CacheEntryStats{
			Key:          entry.Key,
			Size:         entry.Size,
			Age:          time.Since(entry.CreatedAt),
			LastAccessed: entry.LastAccessed,
			TTL:          entry.TTL,
		})
	}

	return stats
}

// CacheStats represents cache statistics
type CacheStats struct {
	EntryCount  int
	CurrentSize int64
	MaxSize     int64
	HitCount    int64
	MissCount   int64
	Entries     []CacheEntryStats
}

// CacheEntryStats represents statistics for a single cache entry
type CacheEntryStats struct {
	Key          string
	Size         int64
	Age          time.Duration
	LastAccessed time.Time
	TTL          time.Duration
}

// ImportState imports state from a file into cache
func (c *StateCache) ImportState(ctx context.Context, key string, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("reading state file: %w", err)
	}

	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return fmt.Errorf("parsing state file: %w", err)
	}

	return c.Put(ctx, key, &state, map[string]interface{}{
		"imported_from": path,
		"imported_at":   time.Now(),
	})
}

// ExportState exports state from cache to a file
func (c *StateCache) ExportState(ctx context.Context, key string, path string) error {
	state, err := c.Get(ctx, key)
	if err != nil {
		return err
	}

	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling state: %w", err)
	}

	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("writing state file: %w", err)
	}

	return nil
}

// Refresh reloads state from the original source
func (c *StateCache) Refresh(ctx context.Context, key string) error {
	c.mu.RLock()
	entry, exists := c.entries[key]
	c.mu.RUnlock()

	if !exists {
		return fmt.Errorf("key %s not found", key)
	}

	state, err := c.loadStateFromFile(entry.Path)
	if err != nil {
		return err
	}

	c.mu.Lock()
	entry.State = state
	entry.LastAccessed = time.Now()
	c.mu.Unlock()

	return nil
}

// Compare compares two cached states
func (c *StateCache) Compare(ctx context.Context, key1, key2 string) (*StateDiff, error) {
	state1, err := c.Get(ctx, key1)
	if err != nil {
		return nil, fmt.Errorf("getting state %s: %w", key1, err)
	}

	state2, err := c.Get(ctx, key2)
	if err != nil {
		return nil, fmt.Errorf("getting state %s: %w", key2, err)
	}

	diff := &StateDiff{
		Key1:             key1,
		Key2:             key2,
		VersionChanged:   state1.Version != state2.Version,
		SerialChanged:    state1.Serial != state2.Serial,
		ResourcesAdded:   []string{},
		ResourcesRemoved: []string{},
		ResourcesChanged: []string{},
		OutputsAdded:     []string{},
		OutputsRemoved:   []string{},
		OutputsChanged:   []string{},
	}

	// Compare resources
	resources1 := make(map[string]StateResource)
	resources2 := make(map[string]StateResource)

	for _, r := range state1.Resources {
		resources1[r.Address] = r
	}

	for _, r := range state2.Resources {
		resources2[r.Address] = r
	}

	for addr := range resources1 {
		if _, exists := resources2[addr]; !exists {
			diff.ResourcesRemoved = append(diff.ResourcesRemoved, addr)
		} else {
			// Check if changed (simplified comparison)
			if resources1[addr].Type != resources2[addr].Type ||
			   resources1[addr].Name != resources2[addr].Name {
				diff.ResourcesChanged = append(diff.ResourcesChanged, addr)
			}
		}
	}

	for addr := range resources2 {
		if _, exists := resources1[addr]; !exists {
			diff.ResourcesAdded = append(diff.ResourcesAdded, addr)
		}
	}

	// Compare outputs
	for name := range state1.Outputs {
		if _, exists := state2.Outputs[name]; !exists {
			diff.OutputsRemoved = append(diff.OutputsRemoved, name)
		} else {
			// Check if changed (simplified comparison)
			if state1.Outputs[name].Sensitive != state2.Outputs[name].Sensitive {
				diff.OutputsChanged = append(diff.OutputsChanged, name)
			}
		}
	}

	for name := range state2.Outputs {
		if _, exists := state1.Outputs[name]; !exists {
			diff.OutputsAdded = append(diff.OutputsAdded, name)
		}
	}

	return diff, nil
}

// StateDiff represents differences between two states
type StateDiff struct {
	Key1             string
	Key2             string
	VersionChanged   bool
	SerialChanged    bool
	ResourcesAdded   []string
	ResourcesRemoved []string
	ResourcesChanged []string
	OutputsAdded     []string
	OutputsRemoved   []string
	OutputsChanged   []string
}

// Merge merges multiple cached states
func (c *StateCache) Merge(ctx context.Context, keys []string, targetKey string) error {
	if len(keys) == 0 {
		return fmt.Errorf("no keys provided for merge")
	}

	// Get first state as base
	mergedState, err := c.Get(ctx, keys[0])
	if err != nil {
		return fmt.Errorf("getting base state: %w", err)
	}

	// Merge additional states
	for i := 1; i < len(keys); i++ {
		state, err := c.Get(ctx, keys[i])
		if err != nil {
			return fmt.Errorf("getting state %s: %w", keys[i], err)
		}

		// Merge resources
		mergedState.Resources = append(mergedState.Resources, state.Resources...)

		// Merge outputs
		if mergedState.Outputs == nil {
			mergedState.Outputs = make(map[string]StateOutput)
		}
		for k, v := range state.Outputs {
			mergedState.Outputs[k] = v
		}

		// Update serial to highest
		if state.Serial > mergedState.Serial {
			mergedState.Serial = state.Serial
		}
	}

	// Store merged state
	return c.Put(ctx, targetKey, mergedState, map[string]interface{}{
		"merged_from": keys,
		"merged_at":   time.Now(),
	})
}

// loadStateFromFile loads state from a file
func (c *StateCache) loadStateFromFile(path string) (*State, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading state file: %w", err)
	}

	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return nil, fmt.Errorf("parsing state: %w", err)
	}

	return &state, nil
}

// calculateHash calculates SHA256 hash of data
func (c *StateCache) calculateHash(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

// ensureSpace ensures there is enough space in cache
func (c *StateCache) ensureSpace(requiredSize int64) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.currentSize+requiredSize <= c.maxSize {
		return nil
	}

	// Need to evict entries (LRU)
	type entryAge struct {
		key      string
		accessed time.Time
	}

	entries := make([]entryAge, 0, len(c.entries))
	for key, entry := range c.entries {
		entries = append(entries, entryAge{
			key:      key,
			accessed: entry.LastAccessed,
		})
	}

	// Sort by last accessed (oldest first)
	for i := 0; i < len(entries)-1; i++ {
		for j := i + 1; j < len(entries); j++ {
			if entries[j].accessed.Before(entries[i].accessed) {
				entries[i], entries[j] = entries[j], entries[i]
			}
		}
	}

	// Evict until we have enough space
	for _, e := range entries {
		if c.currentSize+requiredSize <= c.maxSize {
			break
		}

		entry := c.entries[e.key]
		os.Remove(entry.Path)
		c.currentSize -= entry.Size
		delete(c.entries, e.key)
	}

	if c.currentSize+requiredSize > c.maxSize {
		return fmt.Errorf("not enough cache space: required %d, available %d",
			requiredSize, c.maxSize-c.currentSize)
	}

	return nil
}

// startCleanup starts the cleanup routine
func (c *StateCache) startCleanup(period time.Duration) {
	c.cleanupTicker = time.NewTicker(period)

	go func() {
		for {
			select {
			case <-c.cleanupTicker.C:
				c.cleanup()
			case <-c.stopCleanup:
				c.cleanupTicker.Stop()
				return
			}
		}
	}()
}

// cleanup removes expired entries
func (c *StateCache) cleanup() {
	c.mu.Lock()
	defer c.mu.Unlock()

	now := time.Now()
	for key, entry := range c.entries {
		if now.Sub(entry.CreatedAt) > entry.TTL {
			os.Remove(entry.Path)
			c.currentSize -= entry.Size
			delete(c.entries, key)
		}
	}
}

// Close stops the cache and cleanup routine
func (c *StateCache) Close() error {
	close(c.stopCleanup)
	return nil
}

// StreamState streams state content to a writer
func (c *StateCache) StreamState(ctx context.Context, key string, w io.Writer) error {
	c.mu.RLock()
	entry, exists := c.entries[key]
	c.mu.RUnlock()

	if !exists {
		return fmt.Errorf("key %s not found", key)
	}

	file, err := os.Open(entry.Path)
	if err != nil {
		return fmt.Errorf("opening cache file: %w", err)
	}
	defer file.Close()

	_, err = io.Copy(w, file)
	return err
}

// ValidateState validates the structure of cached state
func (c *StateCache) ValidateState(ctx context.Context, key string) error {
	state, err := c.Get(ctx, key)
	if err != nil {
		return err
	}

	// Basic validation
	if state.Version < 3 || state.Version > 5 {
		return fmt.Errorf("unsupported state version: %d", state.Version)
	}

	if state.TerraformVersion == "" {
		return fmt.Errorf("missing terraform version")
	}

	if state.Lineage == "" {
		return fmt.Errorf("missing state lineage")
	}

	return nil
}

// GetResourceByAddress retrieves a specific resource from cached state
func (c *StateCache) GetResourceByAddress(ctx context.Context, key string, address string) (*StateResource, error) {
	state, err := c.Get(ctx, key)
	if err != nil {
		return nil, err
	}

	for _, resource := range state.Resources {
		if resource.Address == address {
			return &resource, nil
		}
	}

	return nil, fmt.Errorf("resource %s not found", address)
}

// GetOutputByName retrieves a specific output from cached state
func (c *StateCache) GetOutputByName(ctx context.Context, key string, name string) (*StateOutput, error) {
	state, err := c.Get(ctx, key)
	if err != nil {
		return nil, err
	}

	if output, exists := state.Outputs[name]; exists {
		return &output, nil
	}

	return nil, fmt.Errorf("output %s not found", name)
}