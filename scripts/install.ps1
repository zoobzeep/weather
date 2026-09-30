$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
	& aftman install
	if ($LASTEXITCODE -ne 0) {
		throw 'Aftman install failed. For first-use trust, run aftman add <owner/tool@version> in a terminal.'
	}
	if (-not (Test-Path -LiteralPath globalTypes.d.luau)) {
		$typeUrl = 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau'
		Invoke-WebRequest $typeUrl -OutFile globalTypes.d.luau
	}
	& rojo sourcemap default.project.json --output sourcemap.json
	if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap failed' }
} finally {
	Pop-Location
}
