$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
	if (-not (Test-Path -LiteralPath globalTypes.d.luau)) { throw 'Run ./scripts/install.ps1 first.' }
	& stylua --check src tests scripts
	if ($LASTEXITCODE -ne 0) { throw 'StyLua check failed. Run: stylua src tests scripts' }
	$sourceFiles = Get-ChildItem src,tests,scripts -Filter *.luau -Recurse
	foreach ($file in $sourceFiles) {
		$lines = [IO.File]::ReadAllLines($file.FullName)
		if ($lines[0] -ne '--!strict') { throw "Missing strict directive: $($file.FullName)" }
		for ($index = 0; $index -lt $lines.Length; $index++) {
			if ($lines[$index].Length -gt 110) { throw "Line too long: $($file.Name):$($index + 1)" }
			if ($lines[$index] -match '^ +\S') { throw "Space indentation: $($file.Name):$($index + 1)" }
			if ($index -gt 0 -and $lines[$index] -match '--') {
				throw "Code comments are not allowed: $($file.Name):$($index + 1)"
			}
		}
	}
	& rojo sourcemap default.project.json --output sourcemap.json
	if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap failed' }
	& luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json ./src ./tests
	if ($LASTEXITCODE -ne 0) { throw 'Luau analysis failed' }
	New-Item -ItemType Directory -Force build | Out-Null
	& rojo build default.project.json --output build/weather.rbxlx
	if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed' }
	& lune run scripts/RunChecks.luau
	if ($LASTEXITCODE -ne 0) { throw 'Weather checks failed' }
	Write-Output 'PASS: formatting, conventions, strict analysis, Rojo build, and executable checks'
} finally {
	Pop-Location
}
