@{
    ExcludeRules = @(
        # setup.ps1 and install.ps1 are interactive console installers.
        # Write-Host is correct here — it writes directly to the visible console,
        # which Write-Output does not reliably do when called from a .bat file.
        'PSAvoidUsingWriteHost',
        # Scripts use ASCII-only output; UTF-8 BOM is intentionally omitted
        # to avoid breaking cross-platform tooling.
        'PSUseBOMForUnicodeEncodedFile'
    )
}
