# Clean up and destroy EKS cluster and related resources
# - Diagnoses common blockers when terraform destroy gets stuck
# - Proactively removes Helm ALB controller, EKS add-ons, nodegroups
# - Cleans Kubernetes-created ELBs/NLBs and target groups in the VPC
# - Retries terraform destroy at the end

param(
  [string]$Region = 'eu-west-2',
  [string]$Profile = $env:AWS_PROFILE,
  [string]$ProjectName = 'teaching-eks',
  [string]$ClusterName,
  [switch]$SkipHelmRemoval,
  [switch]$SkipCertManagerRemoval,
  [switch]$SkipAddonsRemoval,
  [switch]$SkipK8sLBsCleanup
)

$ErrorActionPreference = 'Stop'
$global:PSNativeCommandUseErrorActionPreference = $false

if (-not $ClusterName -or $ClusterName.Trim() -eq '') {
  $ClusterName = "$ProjectName-cluster"
}

function Section($msg) {
  Write-Host "`n==== $msg ====" -ForegroundColor Cyan
}

function Cmd-Exists($name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function AwsArgs() {
  $args = @('--region', $Region)
  if ($Profile -and $Profile.Trim() -ne '') { $args += @('--profile', $Profile) }
  return $args
}

function AwsJson($svc, $op, $extraArgs) {
  try {
    $args = (AwsArgs) + @($svc, $op) + $extraArgs + @('--output','json')
    $raw = & aws @args 2>$null
    if (-not $raw) { return $null }
    try { return $raw | ConvertFrom-Json } catch { return $null }
  } catch { return $null }
}

function AwsText($svc, $op, $extraArgs) {
  try {
    $args = (AwsArgs) + @($svc, $op) + $extraArgs + @('--output','text')
    return (& aws @args 2>$null)
  } catch { return $null }
}

function Try-Aws([scriptblock]$block) {
  try { & $block; return $true } catch { Write-Host ("[warn] " + $_.Exception.Message) -ForegroundColor Yellow; return $false }
}

function Wait-Until($ScriptBlock, [int]$Seconds = 600, [int]$Interval = 10, [string]$Desc = 'condition') {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $ok = & $ScriptBlock
      if ($ok) { return $true }
    } catch { }
    Start-Sleep -Seconds $Interval
  }
  Write-Host "[warn] Timed out waiting for $Desc after ${Seconds}s" -ForegroundColor Yellow
  return $false
}

function Get-VpcId() {
  $out = AwsText ec2 describe-vpcs @('--filters', "Name=tag:Name,Values=$ProjectName-vpc", '--query', 'Vpcs[0].VpcId')
  if ($out -and $out -ne 'None') { return $out.Trim() }
  return $null
}

function Diagnose-State() {
  Section "Diagnose current AWS/EKS state"

  $id = Try-Aws { AwsJson sts get-caller-identity @() }
  if ($id) {
    $idj = AwsJson sts get-caller-identity @()
    if ($idj) { Write-Host ("Caller: acct=" + $idj.Account + ", arn=" + $idj.Arn) }
  }

  $cluster = Try-Aws { AwsJson eks describe-cluster @('--name', $ClusterName) }
  if ($cluster) {
    $cj = AwsJson eks describe-cluster @('--name', $ClusterName)
    if ($cj) { Write-Host ("EKS cluster status: " + $cj.cluster.status) }
  } else {
    Write-Host "EKS cluster not found or no access." -ForegroundColor Yellow
  }

  $ng = Try-Aws { AwsJson eks list-nodegroups @('--cluster-name', $ClusterName) }
  if ($ng) {
    $ngj = AwsJson eks list-nodegroups @('--cluster-name', $ClusterName)
    Write-Host ("Nodegroups: " + ($ngj.nodegroups -join ', '))
  }

  $addons = Try-Aws { AwsJson eks list-addons @('--cluster-name', $ClusterName) }
  if ($addons) {
    $aj = AwsJson eks list-addons @('--cluster-name', $ClusterName)
    Write-Host ("Add-ons: " + ($aj.addons -join ', '))
  }

  $vpcId = Get-VpcId
  if ($vpcId) { Write-Host ("VPC: $vpcId (tag:Name=$ProjectName-vpc)") }

  if ($vpcId) {
    $lbArns = Try-Aws { AwsText elbv2 describe-load-balancers @('--query', "LoadBalancers[?VpcId=='$vpcId'].LoadBalancerArn") }
    if ($lbArns) { Write-Host ("ELBv2 LBs in VPC: " + ($lbArns -split '\s+' | Where-Object { $_ }) -join ', ') }

    $clbs = Try-Aws { AwsJson elb describe-load-balancers @() }
    if ($clbs) {
      $names = @()
      ($clbs.LoadBalancerDescriptions | Where-Object { $_.VPCId -eq $vpcId }) | ForEach-Object { $names += $_.LoadBalancerName }
      if ($names.Count -gt 0) { Write-Host ("Classic ELBs in VPC: " + ($names -join ', ')) }
    }
  }
}

function Ensure-Kubeconfig() {
  if (-not (Cmd-Exists aws)) { return $false }
  $ok = Try-Aws { AwsText eks update-kubeconfig @('--name', $ClusterName) | Out-Null }
  return $ok
}

function Remove-HelmAlbController() {
  if ($SkipHelmRemoval) { return }
  if (-not (Cmd-Exists helm)) { Write-Host "helm not found, skipping Helm removal." -ForegroundColor Yellow; return }
  if (-not (Ensure-Kubeconfig)) { Write-Host "Could not set kubeconfig, skipping Helm removal." -ForegroundColor Yellow; return }

  try {
    $status = & helm status aws-load-balancer-controller -n kube-system 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Uninstalling Helm release aws-load-balancer-controller..."
      & helm uninstall aws-load-balancer-controller -n kube-system --wait
    } else {
      Write-Host "Helm release aws-load-balancer-controller not present."
    }
  } catch {
    Write-Host ("[warn] Helm uninstall error: " + $_.Exception.Message) -ForegroundColor Yellow
  }
}

function Remove-CertManager() {
  if ($SkipCertManagerRemoval) { return }
  if (-not (Cmd-Exists helm)) { Write-Host "helm not found, skipping cert-manager removal." -ForegroundColor Yellow; return }
  if (-not (Ensure-Kubeconfig)) { Write-Host "Could not set kubeconfig, skipping cert-manager removal." -ForegroundColor Yellow; return }

  try {
    $status = & helm status cert-manager -n cert-manager 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Deleting Issuer and Secret created for teaching CSR signer (if present)..."
      & kubectl -n cert-manager delete issuer user-ca-issuer --ignore-not-found | Out-Null
      & kubectl -n cert-manager delete secret user-ca --ignore-not-found | Out-Null

      Write-Host "Uninstalling Helm release cert-manager..."
      & helm uninstall cert-manager -n cert-manager --wait
    } else {
      Write-Host "Helm release cert-manager not present."
    }
  } catch {
    Write-Host ("[warn] cert-manager uninstall error: " + $_.Exception.Message) -ForegroundColor Yellow
  }
}

function Remove-EksAddons() {
  if ($SkipAddonsRemoval) { return }
  $addons = AwsJson eks list-addons @('--cluster-name', $ClusterName)
  if (-not $addons) { return }
  foreach ($name in $addons.addons) {
    Write-Host "Deleting EKS add-on: $name"
    Try-Aws { & aws @(AwsArgs) eks delete-addon --cluster-name $ClusterName --addon-name $name | Out-Null } | Out-Null
  }
  Wait-Until {
    $a = AwsJson eks list-addons @('--cluster-name', $ClusterName)
    return ($a -and $a.addons.Count -eq 0)
  } 300 10 "all EKS add-ons deleted" | Out-Null
}

function Remove-Nodegroups() {
  $ng = AwsJson eks list-nodegroups @('--cluster-name', $ClusterName)
  if (-not $ng) { return }
  foreach ($n in $ng.nodegroups) {
    Write-Host "Deleting nodegroup: $n"
    Try-Aws { & aws @(AwsArgs) eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name $n | Out-Null } | Out-Null
  }
  Wait-Until {
    $cur = AwsJson eks list-nodegroups @('--cluster-name', $ClusterName)
    return ($cur -and $cur.nodegroups.Count -eq 0)
  } 1200 15 "nodegroups deleted" | Out-Null
}

function Remove-K8sLoadBalancersAndTGs() {
  if ($SkipK8sLBsCleanup) { return }
  $vpcId = Get-VpcId
  if (-not $vpcId) { Write-Host "VPC not found by tag Name=$ProjectName-vpc, skipping ELB cleanup." -ForegroundColor Yellow; return }

  # ALB/NLB (ELBv2)
  $lbArnsText = AwsText elbv2 describe-load-balancers @('--query', "LoadBalancers[?VpcId=='$vpcId'].LoadBalancerArn")
  $lbArns = @()
  if ($lbArnsText) { $lbArns = ($lbArnsText -split '\s+' | Where-Object { $_ }) }
  foreach ($arn in $lbArns) {
    $tagsDoc = AwsJson elbv2 describe-tags @('--resource-arns', $arn)
    $hasK8sTag = $false
    if ($tagsDoc -and $tagsDoc.TagDescriptions.Count -gt 0) {
      foreach ($t in $tagsDoc.TagDescriptions[0].Tags) {
        if ($t.Key -eq "kubernetes.io/cluster/$ClusterName") { $hasK8sTag = $true; break }
      }
    }
    if ($hasK8sTag) {
      Write-Host "Deleting ELBv2: $arn"
      Try-Aws { & aws @(AwsArgs) elbv2 delete-load-balancer --load-balancer-arn $arn | Out-Null } | Out-Null
    }
  }

  # Classic ELB
  $clbs = AwsJson elb describe-load-balancers @()
  if ($clbs) {
    foreach ($lb in ($clbs.LoadBalancerDescriptions | Where-Object { $_.VPCId -eq $vpcId })) {
      $name = $lb.LoadBalancerName
      $tags = AwsJson elb describe-tags @('--load-balancer-names', $name)
      $hasK8sTag = $false
      if ($tags -and $tags.TagDescriptions.Count -gt 0) {
        foreach ($t in $tags.TagDescriptions[0].Tags) {
          if ($t.Key -eq "kubernetes.io/cluster/$ClusterName") { $hasK8sTag = $true; break }
        }
      }
      if ($hasK8sTag) {
        Write-Host "Deleting Classic ELB: $name"
        Try-Aws { & aws @(AwsArgs) elb delete-load-balancer --load-balancer-name $name | Out-Null } | Out-Null
      }
    }
  }

  # Target groups left behind by k8s
  $tgs = AwsJson elbv2 describe-target-groups @('--query', "TargetGroups[?VpcId=='$vpcId']")
  if ($tgs) {
    foreach ($tg in $tgs) {
      $tgArn = $tg.TargetGroupArn
      $t = AwsJson elbv2 describe-tags @('--resource-arns', $tgArn)
      $isK8s = $false
      if ($t -and $t.TagDescriptions.Count -gt 0) {
        foreach ($pair in $t.TagDescriptions[0].Tags) {
          if ($pair.Key -eq "kubernetes.io/cluster/$ClusterName") { $isK8s = $true; break }
        }
      }
      if ($isK8s) {
        Write-Host "Deleting Target Group: $($tg.TargetGroupName)"
        Try-Aws { & aws @(AwsArgs) elbv2 delete-target-group --target-group-arn $tgArn | Out-Null } | Out-Null
      }
    }
  }
}

function Terraform-Destroy($label) {
  Section "Terraform destroy ($label)"
  $tfDir = Join-Path $PSScriptRoot "."
  Push-Location $tfDir
  try {
    & terraform init -backend-config=backend.tfvars -reconfigure | Write-Output
    & terraform destroy -var-file="terraform.tfvars" -auto-approve -input=false
  } finally {
    Pop-Location
  }
}

function Remove-LocalArtifacts() {
  Section "Remove local Terraform artifacts"
  try {
    $paths = @(
      (Join-Path $PSScriptRoot 'out'),
      (Join-Path $PSScriptRoot 'tfplan'),
      (Join-Path $PSScriptRoot '.terraform')
    )
    foreach ($p in $paths) {
      if (Test-Path $p) {
        Write-Host "Removing $p"
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $p
      }
    }
  } catch {
    Write-Host ("[warn] Local cleanup error: " + $_.Exception.Message) -ForegroundColor Yellow
  }
}

# Run
Section "Starting cleanup for cluster $ClusterName in $Region"
Diagnose-State

Section "Pre-destroy cleanup"
Remove-CertManager
Remove-HelmAlbController
Remove-EksAddons
Remove-Nodegroups
Remove-K8sLoadBalancersAndTGs

Terraform-Destroy "after cleanup"

Remove-LocalArtifacts

Section "Final diagnostics"
Diagnose-State

Write-Host "Cleanup script completed." -ForegroundColor Green
