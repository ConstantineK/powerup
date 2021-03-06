﻿$commandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
$here = if ($PSScriptRoot) { $PSScriptRoot } else {	(Get-Item . ).FullName }
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\..\internal\Get-ArchiveItems.ps1"
. "$here\..\internal\New-TempWorkspaceFolder.ps1"
. "$here\..\internal\Expand-ArchiveItem.ps1"

$workFolder = New-TempWorkspaceFolder
$packagePath = "$workFolder\PowerUpTest.zip"
$scriptFolder = "$here\etc\install-tests\success"

Describe "$commandName tests" {	
	
	BeforeAll {
		if (Test-Path $packagePath) { Remove-Item $packagePath -Force }
	}
	AfterAll {
		if ($workFolder.Name -like 'PowerUpWorkspace*') { Remove-Item $workFolder -Recurse }
	}
	It "should create a package file" {
		$results = New-PowerUpPackage -ScriptPath "$here\etc\query1.sql" -Name $packagePath
		$results | Should Not Be $null
		$results.Name | Should Be (Split-Path $packagePath -Leaf)
		Test-Path $packagePath | Should Be $true
	}
	It "should contain query files" {
		$results = Get-ArchiveItems $packagePath
		$results | Where-Object Name -eq 'query1.sql' | Should Not Be $null
	}
	It "should contain module files" {
		$results = Get-ArchiveItems $packagePath
		$results | Where-Object Path -eq 'Modules\PowerUp\PowerUp.psd1' | Should Not Be $null
		$results | Where-Object Path -eq 'Modules\PowerUp\bin\DbUp.dll' | Should Not Be $null
	}
	It "should contain config files" {
		$results = Get-ArchiveItems $packagePath
		$results | Where-Object Path -eq 'PowerUp.config.json' | Should Not Be $null
		$results | Where-Object Path -eq 'PowerUp.package.json' | Should Not Be $null
	}
	It "should be able to apply config file" {
		$results = New-PowerUpPackage -ScriptPath "$here\etc\query1.sql" -Name $packagePath -ConfigurationFile "$here\etc\full_config.json" -Force
		$null = Expand-ArchiveItem -Path $packagePath -DestinationPath $workFolder -Item 'PowerUp.config.json'
		$config = Get-Content "$workFolder\PowerUp.config.json" | ConvertFrom-Json
		$config.ApplicationName | Should Be "MyTestApp"
		$config.SqlInstance | Should Be "TestServer"
		$config.Database | Should Be "MyTestDB"
		$config.DeploymentMethod | Should Be "SingleTransaction"
		$config.ConnectionTimeout | Should Be 40
		$config.Encrypt | Should Be $null
		$config.Credential | Should Be $null
		$config.Username | Should Be "TestUser"
		$config.Password | Should Be "TestPassword"
		$config.SchemaVersionTable | Should Be "test.Table"
		$config.Silent | Should Be $true
		$config.Variables | Should Be $null
	}
	It "should accept wildcard input" {
		$results = New-PowerUpPackage -ScriptPath "$here\etc\install-tests\*" -Build 'abracadabra' -Name $packagePath -Force
		$results | Should Not Be $null
		$results.Name | Should Be (Split-Path $packagePath -Leaf)
		Test-Path $packagePath | Should Be $true
		$results = Get-ArchiveItems $packagePath
		$results | Where-Object Path -eq 'content\abracadabra\Cleanup.sql' | Should Not Be $null
		$results | Where-Object Path -eq 'content\abracadabra\success\1.sql' | Should Not Be $null
		$results | Where-Object Path -eq 'content\abracadabra\success\2.sql' | Should Not Be $null
		$results | Where-Object Path -eq 'content\abracadabra\success\3.sql' | Should Not Be $null
		$results | Where-Object Path -eq 'content\abracadabra\transactional-failure\1.sql' | Should Not Be $null
		$results | Where-Object Path -eq 'content\abracadabra\transactional-failure\2.sql' | Should Not Be $null
		$results | Where-Object Path -eq 'content\abracadabra\verification\select.sql' | Should Not Be $null
	}
	Context "Negative tests" {
		It "should throw error when scripts with the same relative path is being added" {
			try {
				$result = New-PowerUpPackage -Name $packageNameTest -ScriptPath "$scriptFolder\*", "$scriptFolder\..\transactional-failure\*"
			}
			catch {
				$errorResult = $_
			}
			$errorResult.Exception.Message -join ';' | Should BeLike '*already exists inside this build*'
		}
		It "returns error when path does not exist" {
			try {
				$result = New-PowerUpPackage -ScriptPath 'asduwheiruwnfelwefo\sdfpoijfdsf.sps'
			}
			catch {
				$errorResult = $_
			}
			$errorResult.Exception.Message -join ';' | Should BeLike '*The following path is not valid*'
		}
		It "returns error when config file does not exist" {
			try {
				$result = New-PowerUpPackage -ScriptPath "$here\etc\query1.sql" -Config 'asduwheiruwnfelwefo\sdfpoijfdsf.sps'
			}
			catch {
				$errorResult = $_
			}
			$errorResult.Exception.Message -join ';' | Should BeLike '*Config file * not found. Aborting.*'
		}
	}
}
