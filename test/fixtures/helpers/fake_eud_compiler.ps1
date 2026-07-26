param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SettingsPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($RemainingArguments.Count -ne 0) {
    [Console]::Error.WriteLine("unexpected-arguments=$($RemainingArguments -join ',')")
    exit 91
}

$caseName = [System.IO.Path]::GetFileNameWithoutExtension($SettingsPath)
switch ($caseName) {
    'success' {
        $koreanLog = [string]::Concat(
            [char]0xD55C,
            [char]0xAE00,
            [char]0x20,
            [char]0xB85C,
            [char]0xADF8
        )
        [Console]::Out.WriteLine("settings=$SettingsPath")
        [Console]::Out.WriteLine("stdout=$koreanLog")
        [Console]::Error.WriteLine("stderr=compiler warning")
        exit 0
    }
    'failure' {
        [Console]::Out.WriteLine('stdout=before failure')
        [Console]::Error.WriteLine('stderr=compile failed')
        exit 7
    }
    'hang' {
        [Console]::Out.WriteLine('stdout=waiting')
        Start-Sleep -Seconds 30
        exit 0
    }
    'large-output' {
        $line = 'x' * 4096
        for ($index = 0; $index -lt 128; $index++) {
            [Console]::Out.WriteLine($line)
            [Console]::Error.WriteLine($line)
        }
        exit 0
    }
    'environment' {
        [Console]::Out.WriteLine("visible=$env:VISIBLE_TOKEN")
        [Console]::Out.WriteLine("secret=$env:SECRET_TOKEN")
        exit 0
    }
    default {
        [Console]::Error.WriteLine("unknown-case=$caseName")
        exit 92
    }
}
