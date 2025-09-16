# cleanup_all_vpcs.ps1 - Clean up all VPCs from all regions
$regions = @("us-west-1", "us-west-2", "us-east-1", "us-east-2", "eu-west-1")

foreach ($region in $regions) {
    Write-Host "Processing region: $region"
    
    # Get all VPCs in the region
    $vpcs = aws ec2 describe-vpcs --region $region --query 'Vpcs[*].VpcId' --output text
    
    if ($vpcs) {
        Write-Host "Found VPCs in $region : $vpcs"
        
        $vpcArray = $vpcs -split '\s+' | Where-Object { $_.Trim() -ne "" }
        
        foreach ($vpc in $vpcArray) {
            if ($vpc.Trim()) {
                Write-Host "Cleaning up VPC: $vpc in region: $region"
                
                # Check for NAT Gateways
                $natGateways = aws ec2 describe-nat-gateways --region $region --filter "Name=vpc-id,Values=$vpc" --query 'NatGateways[*].NatGatewayId' --output text
                if ($natGateways) {
                    Write-Host "  Found NAT Gateways: $natGateways"
                    $natArray = $natGateways -split '\s+' | Where-Object { $_.Trim() -ne "" }
                    foreach ($nat in $natArray) {
                        if ($nat.Trim()) {
                            Write-Host "    Deleting NAT Gateway: $nat"
                            aws ec2 delete-nat-gateway --region $region --nat-gateway-id $nat
                        }
                    }
                }
                
                # Wait for NAT Gateways to be deleted
                if ($natGateways) {
                    Write-Host "  Waiting for NAT Gateways to be deleted..."
                    Start-Sleep 60
                }
                
                # Get and delete subnets
                $subnets = aws ec2 describe-subnets --region $region --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[*].SubnetId' --output text
                if ($subnets) {
                    Write-Host "  Found subnets: $subnets"
                    $subnetArray = $subnets -split '\s+' | Where-Object { $_.Trim() -ne "" }
                    foreach ($subnet in $subnetArray) {
                        if ($subnet.Trim()) {
                            Write-Host "    Deleting subnet: $subnet"
                            aws ec2 delete-subnet --region $region --subnet-id $subnet
                        }
                    }
                }
                
                # Get and delete internet gateways
                $igws = aws ec2 describe-internet-gateways --region $region --filters "Name=attachment.vpc-id,Values=$vpc" --query 'InternetGateways[*].InternetGatewayId' --output text
                if ($igws) {
                    Write-Host "  Found internet gateways: $igws"
                    $igwArray = $igws -split '\s+' | Where-Object { $_.Trim() -ne "" }
                    foreach ($igw in $igwArray) {
                        if ($igw.Trim()) {
                            Write-Host "    Detaching internet gateway: $igw"
                            aws ec2 detach-internet-gateway --region $region --internet-gateway-id $igw --vpc-id $vpc
                            Write-Host "    Deleting internet gateway: $igw"
                            aws ec2 delete-internet-gateway --region $region --internet-gateway-id $igw
                        }
                    }
                }
                
                # Get and delete custom route tables
                $routeTables = aws ec2 describe-route-tables --region $region --filters "Name=vpc-id,Values=$vpc" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text
                if ($routeTables) {
                    Write-Host "  Found route tables: $routeTables"
                    $rtArray = $routeTables -split '\s+' | Where-Object { $_.Trim() -ne "" }
                    foreach ($rt in $rtArray) {
                        if ($rt.Trim()) {
                            Write-Host "    Deleting route table: $rt"
                            aws ec2 delete-route-table --region $region --route-table-id $rt
                        }
                    }
                }
                
                # Try to delete the VPC
                Write-Host "  Deleting VPC: $vpc"
                try {
                    aws ec2 delete-vpc --region $region --vpc-id $vpc
                    Write-Host "  Successfully deleted VPC: $vpc"
                } catch {
                    Write-Host "  Failed to delete VPC: $vpc - $($_.Exception.Message)"
                }
            }
        }
    } else {
        Write-Host "No VPCs found in $region"
    }
    Write-Host ""
}

Write-Host "Cleanup completed!"
