<#
.SYNOPSIS
    AWS Control Tower AFT GitOps 4 Repositories Bootstrap Script
.DESCRIPTION
    This script automates the creation of the 4 required GitHub repositories for AWS Control Tower AFT.
    It provisions the repositories as private on GitHub and pushes their initial boilerplate configurations.
.PARAMETER GitHubOwner
    The GitHub username or organization name where the repositories will be created.
    If omitted, the script dynamically queries the authenticated user using GitHub CLI.
.EXAMPLE
    .\bootstrap_aft_repos.ps1 -GitHubOwner "my-org-or-username"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$GitHubOwner
)

# 1. Dependency and Authentication Checks
Write-Host "=== Step 1: Running Pre-flight Checks ===" -ForegroundColor Cyan

# Check if git is installed
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git."
    exit 1
}

# Check if GitHub CLI is installed
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI ('gh') is not installed or not in PATH. Please install it."
    exit 1
}

# Check if authenticated to GitHub
Write-Host "Checking GitHub CLI authentication status..."
$authCheck = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not logged in. Please run 'gh auth login' first to authenticate."
    exit 1
}

# Automatically query GitHub Username if not provided
if ([string]::IsNullOrEmpty($GitHubOwner)) {
    Write-Host "GitHubOwner parameter omitted. Fetching authenticated username..."
    $GitHubOwner = & gh api user --jq ".login"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($GitHubOwner)) {
        Write-Error "Failed to fetch GitHub username. Please explicitly provide -GitHubOwner."
        exit 1
    }
    Write-Host "Automatically detected GitHub Owner: $GitHubOwner" -ForegroundColor Yellow
}

# Define the 4 AFT repositories
$repos = @(
    "aws-landing-zone-aft-account-requests",
    "aws-landing-zone-aft-global-customizations",
    "aws-landing-zone-aft-account-customizations",
    "aws-landing-zone-aft-account-provisioning-customizations"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$boilerplateRoot = Join-Path $scriptRoot "scratch/aft-bootstrap"

# Verify boilerplate directory exists
if (-not (Test-Path $boilerplateRoot)) {
    Write-Error "Boilerplate directory not found at $boilerplateRoot. Please ensure scratch files are present."
    exit 1
}

Write-Host "=== Step 2: Provisioning AFT GitOps Repositories ===" -ForegroundColor Cyan

foreach ($repo in $repos) {
    Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
    Write-Host "Processing Repository: $repo" -ForegroundColor Green
    Write-Host "--------------------------------------------------" -ForegroundColor Gray

    # 2.1 Create Repository on GitHub
    Write-Host "Creating private repository '$GitHubOwner/$repo' on GitHub..."
    # Check if repo already exists to prevent duplicate error
    $repoExists = & gh repo view "$GitHubOwner/$repo" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository '$GitHubOwner/$repo' already exists on GitHub. Skipping repository creation." -ForegroundColor Yellow
    } else {
        & gh repo create "$GitHubOwner/$repo" --private --description "AFT GitOps: $repo"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create repository '$repo' on GitHub. Skipping local push."
            continue
        }
        Write-Host "Successfully created private repository '$GitHubOwner/$repo'." -ForegroundColor Green
    }

    # 2.2 Prepare local repository workspace
    $workDir = Join-Path $env:TEMP "aft-bootstrap-work\$repo"
    if (Test-Path $workDir) {
        Remove-Item -Path $workDir -Recurse -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $workDir | Out-Null

    # Copy boilerplate files
    $sourcePath = Join-Path $boilerplateRoot $repo
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "No boilerplate found for $repo at $sourcePath. Initializing empty repository."
    } else {
        Write-Host "Copying boilerplate templates to temporary workspace..."
        Copy-Item -Path "$sourcePath\*" -Destination $workDir -Recurse -Force
    }

    # 2.3 Initialize Git and push to remote
    Push-Location $workDir
    try {
        Write-Host "Initializing Git local repository..."
        & git init | Out-Null
        & git config user.name "AFT Bootstrapper"
        & git config user.email "aft-bootstrap@corp.internal"
        
        Write-Host "Adding files and committing..."
        & git add .
        & git commit -m "initial commit: deploy AFT boilerplate code" | Out-Null
        & git branch -M main

        Write-Host "Pushing initial codebase to GitHub..."
        & git remote add origin "https://github.com/$GitHubOwner/$repo.git"
        & git push -u origin main --force
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully initialized and pushed $repo to GitHub." -ForegroundColor Green
        } else {
            Write-Error "Failed to push local commits to GitHub for $repo."
        }
    }
    finally {
        Pop-Location
        # Cleanup temporary workspace
        if (Test-Path $workDir) {
            Remove-Item -Path $workDir -Recurse -Force | Out-Null
        }
    }
}

Write-Host "`n=== Process Complete ===" -ForegroundColor Cyan
Write-Host "All 4 AFT GitOps repositories have been successfully processed." -ForegroundColor Green
