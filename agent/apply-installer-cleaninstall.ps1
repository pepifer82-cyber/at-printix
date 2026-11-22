param([Parameter(Mandatory = $true)][string]$SourceRoot)

$ErrorActionPreference = 'Stop'
$issPath = Join-Path $SourceRoot 'AandTPrinterAgent.iss'
if (-not (Test-Path $issPath)) { throw "No se encontró $issPath" }
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$iss = [System.IO.File]::ReadAllText($issPath, [System.Text.Encoding]::UTF8)

# Version update only: the project activation serial is never embedded in this installer.
$iss = $iss.Replace('#define MyAppVersion "0.5.3"', '#define MyAppVersion "0.5.4"')
$iss = $iss.Replace('VersionInfoVersion=0.5.3.0', 'VersionInfoVersion=0.5.4.0')
$iss = $iss.Replace('VersionInfoProductVersion=0.5.3', 'VersionInfoProductVersion=0.5.4')
$iss = $iss.Replace('OutputBaseFilename=Instalar_ATPrinterAgent_v0.5.3', 'OutputBaseFilename=Instalar_ATPrinterAgent_v0.5.4')
$iss = [regex]::Replace($iss, '(?m)^\s*LegacyRemoved: Boolean;\r?\n', '')

$helpers = @'
{ Quita las comillas exteriores de una ruta. }
function StripOuterQuotes(const S: String): String;
var
  closingQuote: Integer;
begin
  Result := Trim(S);
  if (Length(Result) > 0) and (Copy(Result, 1, 1) = '"') then
  begin
    closingQuote := Pos('"', Copy(Result, 2, Length(Result) - 1));
    if closingQuote > 0 then Result := Copy(Result, 2, closingQuote - 1);
  end
  else
  begin
    closingQuote := Pos(' ', Result);
    if closingQuote > 0 then Result := Copy(Result, 1, closingQuote - 1);
  end;
end;

{ Detecta unicamente instalaciones de A&T por AppId historico o nombre exacto. }
procedure ScanPreviousAandT(Root: Integer; List: TStringList);
var
  Names: TArrayOfString;
  i: Integer;
  Base, key, dn, un: String;
  isCurrent, isLegacy, isNamedAandT: Boolean;
begin
  Base := 'Software\Microsoft\Windows\CurrentVersion\Uninstall';
  if not RegGetSubkeyNames(Root, Base, Names) then Exit;
  for i := 0 to GetArrayLength(Names) - 1 do
  begin
    key := Base + '\' + Names[i];
    dn := '';
    if not RegQueryStringValue(Root, key, 'DisplayName', dn) then dn := '';
    isCurrent := Pos(CurrentAppIdNeedle, Uppercase(Names[i])) > 0;
    isLegacy := Pos(LegacyAppIdNeedle, Uppercase(Names[i])) > 0;
    isNamedAandT := (Pos('A&T PRINTER AGENT', Uppercase(dn)) > 0) or
                    (Pos('AANDT PRINTER AGENT', Uppercase(dn)) > 0);
    if not (isCurrent or isLegacy or isNamedAandT) then Continue;
    if dn = '' then dn := 'A&T Printer Agent';
    un := '';
    if GetQuietOrNormalUninstall(Root, key, un) then List.Add(dn + '|' + un);
  end;
end;

function ProfileHasAgentData(const ProfilePath: String): Boolean;
var
  base: String;
begin
  base := AddBackslash(ProfilePath);
  Result := DirExists(base + 'AppData\Local\ATPrinterAgent') or
            DirExists(base + 'AppData\Local\ATPrinterAgent-v043-migration') or
            DirExists(base + 'AppData\Local\ATPrinterAgent-v041') or
            DirExists(base + 'AppData\Local\ATPrinterAgent-v040') or
            DirExists(base + 'AppData\Roaming\ATPrinterAgent');
end;

function AnyAgentDataArtifacts(): Boolean;
var
  Names: TArrayOfString;
  i: Integer;
  profile: String;
begin
  Result := ProfileHasAgentData(ExpandConstant('{userprofile}')) or
            DirExists(ExpandConstant('{commonappdata}\ATPrinterAgent'));
  if Result then Exit;
  if RegGetSubkeyNames(HKEY_LOCAL_MACHINE,
       'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', Names) then
    for i := 0 to GetArrayLength(Names) - 1 do
      if RegQueryStringValue(HKEY_LOCAL_MACHINE,
           'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + Names[i],
           'ProfileImagePath', profile) then
        if ProfileHasAgentData(profile) then
        begin
          Result := True;
          Exit;
        end;
end;
'@

$helpersPattern = '(?s)\{ Quita las comillas exteriores de una ruta\. \}.*?(?=\r?\nfunction CurrentInstallVersion\(\): String;)'
$helpersRx = [regex]::new($helpersPattern)
$issNew = $helpersRx.Replace($iss, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $helpers }, 1)
if ($issNew -eq $iss -or -not $issNew.Contains('procedure ScanPreviousAandT')) {
    throw 'No se pudo sustituir el detector anterior de instalaciones.'
}
$iss = $issNew

$lifecycle = @'
function InitializeSetup(): Boolean;
var
  List: TStringList;
  i, sep: Integer;
  item, details, version: String;
  foundPrior: Boolean;
begin
  FullCleanRequested := HasCommandLineParam('/FULLCLEAN') and IsSilentInstall();
  version := CurrentInstallVersion();
  PreviousVersionInstalled := version <> '';

  // Actualizaciones silenciosas desde el panel conservan serial/configuracion.
  if IsSilentInstall() and (not FullCleanRequested) then
  begin
    Result := True;
    Exit;
  end;

  List := TStringList.Create;
  try
    List.Sorted := True;
    List.Duplicates := dupIgnore;
    ScanPreviousAandT(HKEY_LOCAL_MACHINE, List);
    ScanPreviousAandT(HKEY_CURRENT_USER, List);
    foundPrior := (List.Count > 0) or AnyAgentDataArtifacts();

    if foundPrior and (not FullCleanRequested) then
    begin
      details := '';
      for i := 0 to List.Count - 1 do
      begin
        item := List[i];
        sep := Pos('|', item);
        if sep > 0 then details := details + '  - ' + Copy(item, 1, sep - 1) + #13#10;
      end;
      if details = '' then details := '  - Datos/configuración residual de A&T detectados.' + #13#10;

      if MsgBox('Se detectó una instalación anterior de A&T Printer Agent o datos de una versión previa:' + #13#10 #13#10 +
                details + #13#10 +
                '¿Desinstalar las versiones anteriores y borrar sus activaciones/configuraciones antes de instalar A&T Printer Agent 0.5.4?' + #13#10 #13#10 +
                'Sí: desinstala los agentes A&T anteriores y deja esta instalación completamente limpia. Después deberás ingresar manualmente el serial del proyecto.' + #13#10 +
                'No: cancela la instalación sin modificar nada.',
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
        FullCleanRequested := True
      else
      begin
        Result := False;
        Exit;
      end;
    end;
  finally
    List.Free;
  end;

  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  List: TStringList;
  i, sep, rcode: Integer;
  item, un, path: String;
  launched: Boolean;
begin
  Result := '';
  if not FullCleanRequested then Exit;

  List := TStringList.Create;
  try
    List.Sorted := True;
    List.Duplicates := dupIgnore;
    ScanPreviousAandT(HKEY_LOCAL_MACHINE, List);
    ScanPreviousAandT(HKEY_CURRENT_USER, List);

    // Desinstala cada version A&T registrada antes de copiar archivos nuevos.
    for i := 0 to List.Count - 1 do
    begin
      item := List[i];
      sep := Pos('|', item);
      if sep <= 0 then Continue;
      un := Copy(item, sep + 1, Length(item));
      path := StripOuterQuotes(un);
      if path = '' then Continue;

      launched := Exec(path, '/VERYSILENT /FULLCLEAN /NORESTART /SUPPRESSMSGBOXES',
                       '', SW_HIDE, ewWaitUntilTerminated, rcode);
      if (not launched) or (rcode <> 0) then
      begin
        Result := 'No se pudo desinstalar la version anterior de A&T (' + Copy(item, 1, sep - 1) + '). Codigo: ' + IntToStr(rcode) + '. Se cancelo la instalacion para no mezclar archivos.';
        Exit;
      end;
    end;
  finally
    List.Free;
  end;

  Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM ATPrinterAgent.exe /T /F',
       '', SW_HIDE, ewWaitUntilTerminated, rcode);
  WipeAgentArtifacts(False);
end;
'@

$lifecyclePattern = '(?s)function InitializeSetup\(\): Boolean;.*?(?=\r?\nprocedure CurStepChanged\(CurStep: TSetupStep\);)'
$lifecycleRx = [regex]::new($lifecyclePattern)
$issNew = $lifecycleRx.Replace($iss, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $lifecycle }, 1)
if ($issNew -eq $iss -or -not $issNew.Contains('ScanPreviousAandT(HKEY_LOCAL_MACHINE, List)')) {
    throw 'No se pudo sustituir el ciclo de instalacion/desinstalacion.'
}
[System.IO.File]::WriteAllText($issPath, $issNew, $utf8NoBom)

$readmePath = Join-Path $SourceRoot 'README.txt'
if (Test-Path $readmePath) {
    $readme = [System.IO.File]::ReadAllText($readmePath, [System.Text.Encoding]::UTF8)
    $readme = $readme.Replace('A&T Printer Agent 0.5.3', 'A&T Printer Agent 0.5.4')
    $readme = $readme.Replace('Instalar_ATPrinterAgent_v0.5.3.exe', 'Instalar_ATPrinterAgent_v0.5.4.exe')
    $readme += [Environment]::NewLine + 'Novedades 0.5.4: el EXE no contiene un serial precargado; el usuario ingresa manualmente el serial del proyecto. La limpieza local no borra proyectos, seriales registrados ni inventario historico de Supabase. Las actualizaciones silenciosas remotas conservan la configuracion. La MAC detectada se sincroniza y el token remoto por instalacion se protege con DPAPI.' + [Environment]::NewLine
    [System.IO.File]::WriteAllText($readmePath, $readme, $utf8NoBom)
}

Write-Host 'Instalador limpio 0.5.4 aplicado correctamente.'
