# Vigila la carpeta Logs de WoW mientras jugás y anota cada vez que el juego vuelca el registro de
# combate a disco: así medimos cada cuánto aparece información nueva para subirla.
# Uso (PowerShell, dejarlo corriendo durante la raid; Ctrl+C para terminar):
#   powershell -ExecutionPolicy Bypass -File vigilar-log.ps1 -Logs "C:\Program Files (x86)\World of Warcraft\_anniversary_\Logs"
param([Parameter(Mandatory = $true)][string]$Logs, [string]$Salida = "$PWD\vigilar-log.csv")

"hora,archivo,bytes,delta_bytes,segundos_desde_anterior" | Out-File -Encoding utf8 $Salida
$prevSize = @{}; $prevTime = $null
Write-Host "Vigilando $Logs (Ctrl+C para terminar). Guardando en $Salida"
while ($true) {
  $f = Get-ChildItem -Path $Logs -Filter 'WoWCombatLog*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($f) {
    $f.Refresh()
    $size = $f.Length
    $prev = $prevSize[$f.Name]
    if ($null -ne $prev -and $size -ne $prev) {
      $now = Get-Date
      $gap = if ($prevTime) { [math]::Round(($now - $prevTime).TotalSeconds, 1) } else { '' }
      $delta = $size - $prev
      "{0},{1},{2},{3},{4}" -f $now.ToString('HH:mm:ss'), $f.Name, $size, $delta, $gap | Out-File -Append -Encoding utf8 $Salida
      Write-Host ("{0}  +{1,8:N0} bytes  ({2} s)" -f $now.ToString('HH:mm:ss'), $delta, $gap)
      $prevTime = $now
    }
    $prevSize[$f.Name] = $size
  }
  Start-Sleep -Milliseconds 500
}
