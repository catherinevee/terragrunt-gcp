package testhelpers

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"time"
)

// TestCache represents a test cache
type TestCache struct {
	CacheDir string
	TTL      time.Duration
}

// GetDefaultTestCache returns default test cache configuration
func GetDefaultTestCache() *TestCache {
	return &TestCache{
		CacheDir: ".test-cache",
		TTL:      24 * time.Hour,
	}
}

// GetTestCacheKey generates a cache key based on Terraform files
func GetTestCacheKey(terraformDir string) string {
	hash := md5.New()
	filepath.Walk(terraformDir, func(path string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() {
			hash.Write([]byte(path))
			hash.Write([]byte(info.ModTime().String()))
		}
		return nil
	})
	return hex.EncodeToString(hash.Sum(nil))
}

// GetCachedTestResult retrieves cached test result
func (cache *TestCache) GetCachedTestResult(key string) (*TestResult, bool) {
	cacheFile := filepath.Join(cache.CacheDir, key+".json")

	// Check if cache file exists
	if _, err := os.Stat(cacheFile); os.IsNotExist(err) {
		return nil, false
	}

	// Check if cache is expired
	fileInfo, err := os.Stat(cacheFile)
	if err != nil {
		return nil, false
	}

	if time.Since(fileInfo.ModTime()) > cache.TTL {
		os.Remove(cacheFile)
		return nil, false
	}

	// Read cache file
	data, err := os.ReadFile(cacheFile)
	if err != nil {
		return nil, false
	}

	var result TestResult
	err = json.Unmarshal(data, &result)
	if err != nil {
		return nil, false
	}

	return &result, true
}

// SetCachedTestResult stores test result in cache
func (cache *TestCache) SetCachedTestResult(key string, result *TestResult) error {
	// Create cache directory if it doesn't exist
	err := os.MkdirAll(cache.CacheDir, 0755)
	if err != nil {
		return err
	}

	cacheFile := filepath.Join(cache.CacheDir, key+".json")

	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(cacheFile, data, 0644)
}

// TestResult represents a test result
type TestResult struct {
	Key       string        `json:"key"`
	Status    string        `json:"status"`
	Duration  time.Duration `json:"duration"`
	Tests     int           `json:"tests"`
	Passed    int           `json:"passed"`
	Failed    int           `json:"failed"`
	Skipped   int           `json:"skipped"`
	Timestamp time.Time     `json:"timestamp"`
	Error     string        `json:"error,omitempty"`
}

// ClearCache clears the test cache
func (cache *TestCache) ClearCache() error {
	return os.RemoveAll(cache.CacheDir)
}

// GetCacheSize returns the size of the cache directory
func (cache *TestCache) GetCacheSize() (int64, error) {
	var size int64
	err := filepath.Walk(cache.CacheDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return nil
	})
	return size, err
}

// GetCacheFileCount returns the number of files in the cache
func (cache *TestCache) GetCacheFileCount() (int, error) {
	count := 0
	err := filepath.Walk(cache.CacheDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			count++
		}
		return nil
	})
	return count, err
}

// CleanupExpiredCache removes expired cache files
func (cache *TestCache) CleanupExpiredCache() error {
	return filepath.Walk(cache.CacheDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			if time.Since(info.ModTime()) > cache.TTL {
				return os.Remove(path)
			}
		}
		return nil
	})
}

// GetCacheStats returns cache statistics
func (cache *TestCache) GetCacheStats() (*CacheStats, error) {
	size, err := cache.GetCacheSize()
	if err != nil {
		return nil, err
	}

	fileCount, err := cache.GetCacheFileCount()
	if err != nil {
		return nil, err
	}

	return &CacheStats{
		Size:      size,
		FileCount: fileCount,
		TTL:       cache.TTL,
	}, nil
}

// CacheStats represents cache statistics
type CacheStats struct {
	Size      int64         `json:"size"`
	FileCount int           `json:"file_count"`
	TTL       time.Duration `json:"ttl"`
}

// CopyFile copies a file from src to dst
func CopyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	if err != nil {
		return err
	}

	return destFile.Sync()
}

// FileExists checks if a file exists
func FileExists(filename string) bool {
	_, err := os.Stat(filename)
	return !os.IsNotExist(err)
}

// DirExists checks if a directory exists
func DirExists(dirname string) bool {
	info, err := os.Stat(dirname)
	return !os.IsNotExist(err) && info.IsDir()
}

// CreateDir creates a directory if it doesn't exist
func CreateDir(dirname string) error {
	if !DirExists(dirname) {
		return os.MkdirAll(dirname, 0755)
	}
	return nil
}

// RemoveDir removes a directory and all its contents
func RemoveDir(dirname string) error {
	return os.RemoveAll(dirname)
}

// GetFileSize returns the size of a file
func GetFileSize(filename string) (int64, error) {
	info, err := os.Stat(filename)
	if err != nil {
		return 0, err
	}
	return info.Size(), nil
}

// GetFileModTime returns the modification time of a file
func GetFileModTime(filename string) (time.Time, error) {
	info, err := os.Stat(filename)
	if err != nil {
		return time.Time{}, err
	}
	return info.ModTime(), nil
}
