$path = Join-Path $PSScriptRoot 'test-tone.wav'
$sampleRate = 44100
$seconds = 75
$samples = $sampleRate * $seconds
$dataSize = $samples * 2
$fs = [System.IO.File]::Create($path)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
$bw.Write([int](36 + $dataSize))
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
$bw.Write([int]16)
$bw.Write([int16]1)
$bw.Write([int16]1)
$bw.Write([int]$sampleRate)
$bw.Write([int]($sampleRate * 2))
$bw.Write([int16]2)
$bw.Write([int16]16)
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
$bw.Write([int]$dataSize)
for ($i = 0; $i -lt $samples; $i++) {
  $t = $i / $sampleRate
  $env = [Math]::Min(1.0, $t / 0.5) * [Math]::Min(1.0, ($seconds - $t) / 0.5)
  $v = [int16](11000 * $env * [Math]::Sin(2 * [Math]::PI * 440 * $t))
  $bw.Write($v)
}
$bw.Close()
$fs.Close()
Write-Output "wrote $path $((Get-Item $path).Length) bytes"
