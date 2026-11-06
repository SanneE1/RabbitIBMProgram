unit rabbit_settings;

{All settings of the rabbit model in one registry: each setting has a name, a type, a valid
 range and the variable it sets. The rates file and the command line both go through
 SetSetting, so they share one code path and the same checks.

 Command line (settings interface 2): every argument is --name=value, e.g.
   Rabbit --output_dir=sim --start_year=2017 --end_year=2024 --rates_file=rates.txt
          --habitat_folder=K_maps.kbin --climate_folder=clim --seed=42 --RHD_mode=immunity

 Order of precedence (later wins):
   1. defaults in the code (general_define_units)
   2. the rates file (--rates_file, required)
   3. every other --name=value on the command line

 The rates file has one "name value" pair per line; empty lines, lines starting with # and
 anything after whitespace + # are skipped.
 Unknown names, values that are not valid, values outside their range and a name given twice
 in the file (or twice on the command line) stop the program. Numbers always use '.' as
 decimal mark, whatever the locale.

 Positional arguments (the interface before settings interface 2) are not accepted: every
 argument must be --name=value. See model_settings.md.}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils,
  general_functions, general_define_units;

const
  SETTINGS_INTERFACE = 2;

procedure RegisterSettings;
procedure LoadAllSettings;
procedure CheckSettings;
procedure LogSettings;

implementation

type
  TSettingKind = (skInt, skReal, skWholeReal, skBool, skStr, skEnum);
  PAnsiStr = ^AnsiString;
  PReal = ^Real;

  TSetting = record
    Name: string;
    Kind: TSettingKind;
    Target: Pointer;
    Lo, Hi: real;              // valid range; -Inf / +Inf = unbounded
    Choices: string;           // skEnum: comma separated, the index is the stored value
    Required: boolean;
    Group, Help: string;
    DefaultText: string;
    Source: string;            // 'default', a file name or 'command line'
    PrevText, PrevSource: string;
  end;

var
  Settings: array of TSetting;
  FmtDot: TFormatSettings;
  rates_file_arg: string = '';
  cmd_names, cmd_values: array of string;


{---- errors ---------------------------------------------------------------------------------}

procedure Fail(const msg: string);
begin
  ShowErrorAndExit(msg);
end;


{---- registry -------------------------------------------------------------------------------}

function KindName(k: TSettingKind): string;
begin
  Result := '';
  case k of
    skInt: Result := 'whole number';
    skReal: Result := 'number';
    skWholeReal: Result := 'whole number';
    skBool: Result := '0/1';
    skStr: Result := 'text';
    skEnum: Result := 'one of';
  end;
end;

function ValueText(const s: TSetting): string;
begin
  Result := '';
  case s.Kind of
    skInt: Result := IntToStr(PLongint(s.Target)^);
    skReal, skWholeReal: Result := FloatToStr(PReal(s.Target)^, FmtDot);
    skBool: if PBoolean(s.Target)^ then Result := '1' else Result := '0';
    skStr: Result := PAnsiStr(s.Target)^;
    skEnum: Result := ExtractDelimited(PLongint(s.Target)^ + 1, s.Choices, [',']);
  end;
end;

procedure Add(const AName: string; AKind: TSettingKind; ATarget: Pointer; ARequired: boolean;
              const AGroup, AHelp: string; ALo: real = NegInfinity; AHi: real = Infinity;
              const AChoices: string = '');
var
  n: integer;
begin
  n := Length(Settings);
  SetLength(Settings, n + 1);
  with Settings[n] do
  begin
    Name := AName; Kind := AKind; Target := ATarget; Required := ARequired;
    Group := AGroup; Help := AHelp; Lo := ALo; Hi := AHi; Choices := AChoices;
    Source := 'default'; PrevText := ''; PrevSource := '';
  end;
  if ARequired then Settings[n].DefaultText := '(required)'
  else Settings[n].DefaultText := ValueText(Settings[n]);
end;

procedure RegisterSettings;
const
  RUN = 'Run'; DEM = 'Demographic rates'; DIS = 'Dispersal'; RHD = 'RHD (disease)';
begin
  FmtDot := DefaultFormatSettings;
  FmtDot.DecimalSeparator := '.';
  FmtDot.ThousandSeparator := #0;
  SetLength(Settings, 0);

  {Run}
  Add('output_dir', skStr, @output_dir, True, RUN, 'folder for the output (maps/, RHD logs, settings_used.txt)');
  Add('start_year', skInt, @start_year, True, RUN, 'first simulated year (from January)', 0, 9999);
  Add('end_year', skInt, @end_year, True, RUN, 'last simulated year (to December)', 0, 9999);
  Add('habitat_folder', skStr, @habitat_folder, False, RUN, 'carrying capacity: a K_maps.kbin file, a folder of <year>_<month>.txt maps, or 0 = the static map mapname_rabbit');
  Add('mapname_rabbit', skStr, @mapname_rabbit, False, RUN, 'static carrying capacity map, used when habitat_folder = 0');
  Add('climate_folder', skStr, @climate_folder, True, RUN, 'folder with breeding_months_<year>.txt and consecutive_dry_months_<year>.txt');
  Add('create_all_month_maps', skBool, @create_all_month_maps, False, RUN, '1 = a population map for every month');
  Add('rabbit_start_file', skStr, @rabbit_start_file, False, RUN, '0 = start at carrying capacity, otherwise a map with the starting rabbits per cell');
  Add('seed', skInt, @seed, False, RUN, 'random seed; -1 = none (different every run)', -1, MaxLongint);

  {Demographic rates}
  Add('max_age', skInt, @R_max_age, True, DEM, 'rabbits of this age (months) or older die', 1, 1000);
  Add('young_age', skInt, @R_young_age, True, DEM, 'below this age (months) a rabbit is a juvenile', 0, 1000);
  Add('adult_age', skInt, @R_adult_age, True, DEM, 'from this age (months) reproduction gets r_second_effect', 0, 1000);
  Add('old_age', skInt, @R_old_age, True, DEM, 'from this age (months) reproduction gets r_later_effect', 0, 1000);
  Add('disp_age', skInt, @R_disp_age, True, DEM, 'age (months) at which rabbits disperse', 0, 1000);
  Add('MeanLitSize', skReal, @R_MeanLitSize, True, DEM, 'mean litter size (kits)', 1, 100);
  Add('MinLitSize', skInt, @R_MinLitSize, False, DEM, 'smallest litter (kits)', 1, 100);
  Add('MaxLitSize', skInt, @R_MaxLitSize, False, DEM, 'largest litter (kits)', 1, 100);
  Add('r_int', skReal, @R_r_int, True, DEM, 'reproduction intercept (logit)');
  Add('r_dens_effect', skReal, @R_r_dens_effect, True, DEM, 'reproduction decrease with Kdens (logit)');
  Add('r_second_effect', skReal, @R_r_second_effect, True, DEM, 'reproduction extra from adult_age (logit)');
  Add('r_later_effect', skReal, @R_r_later_effect, True, DEM, 'reproduction extra from old_age (logit)');
  Add('MortP_at_month_old', skReal, @R_MortP_at_month_old, True, DEM, 'share of kits that die in their first month', 0, 1);
  Add('s_int', skReal, @R_s_int, True, DEM, 'survival intercept (logit)');
  Add('s_extra_juv', skReal, @R_s_extra_juv, True, DEM, 'lower survival of juveniles (logit)');
  Add('s_dens_effect', skReal, @R_s_dens_effect, True, DEM, 'survival decrease with Kdens (logit)');
  Add('s_food_effect', skReal, @R_s_food_effect, True, DEM, 'effect of consecutive dry months on survival', 0, Infinity);

  {Dispersal}
  Add('dens_opt', skWholeReal, @R_dens_opt, True, DIS, 'preferred number of rabbits in the destination cell', 0, Infinity);
  Add('lambda', skReal, @R_lambda, True, DIS, 'how strongly rabbits avoid cells far from dens_opt', 0, Infinity);
  Add('sigma', skReal, @R_sigma, True, DIS, 'how quickly the chance of moving falls with distance', 0, Infinity);

  {RHD}
  Add('RHD_mode', skEnum, @RHD_mode, False, RHD, 'disease process', NegInfinity, Infinity, 'none,schedule,immunity');
  Add('RHDFreq_L', skInt, @RHDFreq_L, True, RHD, 'schedule mode: shortest interval between outbreaks (months)', 1, 10000);
  Add('RHDFreq_U', skInt, @RHDFreq_U, True, RHD, 'schedule mode: longest interval between outbreaks (months)', 1, 10000);
  Add('RHDMort_L', skReal, @RHDMort_L, True, RHD, 'schedule mode: lowest share of adults killed per outbreak', 0, 1);
  Add('RHDMort_U', skReal, @RHDMort_U, True, RHD, 'schedule mode: highest share of adults killed per outbreak', 0, 1);
  Add('RHD_min_age', skInt, @RHD_min_age, False, RHD, 'minimum age (months) to be infected', 0, 1000);
  Add('RHD_f_crit', skReal, @RHD_f_crit, False, RHD, 'susceptible share with a 50% outbreak chance in an exposed cell', 0, 1);
  Add('RHD_f_slope', skReal, @RHD_f_slope, False, RHD, 'steepness of the outbreak chance around RHD_f_crit', 0, Infinity);
  Add('RHD_spark', skReal, @RHD_spark, False, RHD, 'chance per occupied cell per month that the virus arrives from outside', 0, 1);
  Add('RHD_spread', skReal, @RHD_spread, False, RHD, 'chance per neighbouring cell with an outbreak last month', 0, 1);
  Add('RHD_mortality', skReal, @RHD_mortality, False, RHD, 'share of infected rabbits that die', 0, 1);
  Add('RHD2_mortality', skReal, @RHD2_mortality, False, RHD, 'as RHD_mortality for RHDV2; -1 = use RHD_mortality', -1, 1);
  Add('RHD1_arrival_year', skInt, @RHD1_arrival_year, False, RHD, 'arrival of RHDV1; 0 = before the simulation', 0, 9999);
  Add('RHD1_arrival_month', skInt, @RHD1_arrival_month, False, RHD, 'arrival month of RHDV1', 1, 12);
  Add('RHD2_arrival_year', skInt, @RHD2_arrival_year, False, RHD, 'arrival of RHDV2; 0 = before the simulation, 9999 = never', 0, 9999);
  Add('RHD2_arrival_month', skInt, @RHD2_arrival_month, False, RHD, 'arrival month of RHDV2', 1, 12);
  Add('RHD_seed_share', skReal, @RHD_seed_share, False, RHD, 'share of occupied cells exposed at an arrival', 0, 1);
  Add('RHD2_cross_immunity', skReal, @RHD2_cross_immunity, False, RHD, 'chance that RHDV1 immunity protects against RHDV2', 0, 1);
  Add('RHD_init_immune_lo', skReal, @RHD_init_immune_lo, False, RHD, 'lowest immune share per cell at the start (after an arrival)', 0, 1);
  Add('RHD_init_immune_hi', skReal, @RHD_init_immune_hi, False, RHD, 'highest immune share per cell at the start (after an arrival)', 0, 1);
  Add('RHD_log', skBool, @RHD_log, False, RHD, '1 = write rhd_outbreaks.csv and rhd_monthly.csv (immunity mode)');
end;

function FindSetting(const AName: string): integer;
var
  i: integer;
begin
  for i := 0 to High(Settings) do
    if Settings[i].Name = AName then Exit(i);
  Result := -1;
end;

{Levenshtein distance, to suggest the closest name for a typing error}
function EditDistance(const a, b: string): integer;
var
  d: array of array of integer;
  i, j, cost: integer;
begin
  SetLength(d, Length(a) + 1, Length(b) + 1);
  for i := 0 to Length(a) do d[i, 0] := i;
  for j := 0 to Length(b) do d[0, j] := j;
  for i := 1 to Length(a) do
    for j := 1 to Length(b) do
    begin
      if LowerCase(a[i]) = LowerCase(b[j]) then cost := 0 else cost := 1;
      d[i, j] := Min(Min(d[i - 1, j] + 1, d[i, j - 1] + 1), d[i - 1, j - 1] + cost);
    end;
  Result := d[Length(a), Length(b)];
end;

function Suggestion(const AName: string): string;
var
  i, best, dist: integer;
begin
  Result := '';
  best := Max(3, Length(AName) div 3) + 1;
  for i := 0 to High(Settings) do
  begin
    dist := EditDistance(AName, Settings[i].Name);
    if dist < best then
    begin
      best := dist;
      Result := '; did you mean ' + Settings[i].Name + '?';
    end;
  end;
end;


{---- setting values ---------------------------------------------------------------------------}

procedure SetSetting(const AName, AValue, ASource: string);
var
  idx, code, iv, k: integer;
  rv: real;
  v, before: string;
begin
  if AName = 'rates_file' then
    Fail('"rates_file" can only be given on the command line (--rates_file=...), not in ' + ASource);

  idx := FindSetting(AName);
  if idx < 0 then
    Fail('Unknown setting "' + AName + '" in ' + ASource + Suggestion(AName));

  with Settings[idx] do
  begin
    if Source = ASource then
      Fail('Setting "' + AName + '" is given twice in ' + ASource);

    v := Trim(AValue);
    before := ValueText(Settings[idx]);

    case Kind of
      skInt:
        begin
          Val(v, iv, code);
          if code <> 0 then Fail(AName + ' = "' + v + '" is not a whole number (' + ASource + ')');
          if (iv < Lo) or (iv > Hi) then
            Fail(AName + ' = ' + v + ' is outside its valid range ' + FloatToStr(Lo, FmtDot) + ' to ' +
                 FloatToStr(Hi, FmtDot) + ' (' + ASource + ')');
          PLongint(Target)^ := iv;
        end;
      skReal, skWholeReal:
        begin
          Val(v, rv, code);
          if (code <> 0) or IsNan(rv) or IsInfinite(rv) then
            Fail(AName + ' = "' + v + '" is not a number; use "." as decimal mark (' + ASource + ')');
          if (Kind = skWholeReal) and (Frac(rv) <> 0) then
            Fail(AName + ' = ' + v + ' must be a whole number (' + ASource + ')');
          if (rv < Lo) or (rv > Hi) then
            Fail(AName + ' = ' + v + ' is outside its valid range ' + FloatToStr(Lo, FmtDot) + ' to ' +
                 FloatToStr(Hi, FmtDot) + ' (' + ASource + ')');
          PReal(Target)^ := rv;
        end;
      skBool:
        begin
          if (v = '1') or (LowerCase(v) = 'true') then PBoolean(Target)^ := True
          else if (v = '0') or (LowerCase(v) = 'false') then PBoolean(Target)^ := False
          else Fail(AName + ' = "' + v + '" must be 0 or 1 (' + ASource + ')');
        end;
      skStr:
        begin
          if v = '' then Fail(AName + ' has no value (' + ASource + ')');
          PAnsiStr(Target)^ := v;
        end;
      skEnum:
        begin
          iv := -1;
          for k := 1 to WordCount(Choices, [',']) do
            if ExtractDelimited(k, Choices, [',']) = v then iv := k - 1;
          if iv < 0 then
            Fail(AName + ' must be one of ' + Choices + ', not "' + v + '" (' + ASource + ')');
          PLongint(Target)^ := iv;
        end;
    end;

    PrevText := before;
    PrevSource := Source;
    Source := ASource;
  end;
end;

procedure ReadSettingsFile(const FileName: string);
var
  F: TextFile;
  Line, AName, AValue, Source: string;
  p: integer;
begin
  if not FileExists(FileName) then Fail('Settings file not found: ' + FileName);
  Source := FileName;
  AssignFile(F, FileName);
  Reset(F);
  while not EOF(F) do
  begin
    ReadLn(F, Line);
    Line := Trim(Line);
    if (Line = '') or (Line[1] = '#') then Continue;
    p := 1;
    while (p <= Length(Line)) and not (Line[p] in [' ', #9]) do Inc(p);
    AName := Copy(Line, 1, p - 1);
    AValue := Trim(Copy(Line, p + 1, MaxInt));
    {a comment after the value: whitespace followed by #}
    p := Pos(' #', AValue);
    if p = 0 then p := Pos(#9'#', AValue);
    if p > 0 then AValue := Trim(Copy(AValue, 1, p - 1));
    if AValue = '' then Fail('No value for "' + AName + '" in ' + FileName);
    SetSetting(AName, AValue, Source);
  end;
  CloseFile(F);
end;


{---- command line -----------------------------------------------------------------------------}

procedure PrintVersion;
begin
  WriteLn('Rabbit population model');
  WriteLn('settings_interface ', SETTINGS_INTERFACE);
end;

procedure PrintHelp;
var
  i: integer;
  g, range: string;
begin
  PrintVersion;
  WriteLn;
  WriteLn('Usage: every argument is --name=value. Command line only:');
  WriteLn('  --rates_file=<file>   rates file (required): "name value" lines, any setting below');
  WriteLn('  --version, --help');
  WriteLn('Later wins: code defaults < rates file < other --name=value.');
  g := '';
  for i := 0 to High(Settings) do
    with Settings[i] do
    begin
      if Group <> g then
      begin
        g := Group;
        WriteLn;
        WriteLn(g, ':');
      end;
      range := '';
      if Kind = skEnum then range := ' [' + Choices + ']'
      else if not (IsInfinite(Lo) and IsInfinite(Hi)) and (Kind in [skInt, skReal, skWholeReal]) then
        range := ' [' + IfThen(IsInfinite(Lo), '', FloatToStr(Lo, FmtDot)) + ' .. ' +
                 IfThen(IsInfinite(Hi), '', FloatToStr(Hi, FmtDot)) + ']';
      WriteLn('  ', Name, ' (', KindName(Kind), range, ', default ', DefaultText, '): ', Help);
    end;
end;

procedure AddCommandValue(const AName, AValue: string);
var
  i, n: integer;
begin
  if AName = 'rates_file' then
  begin
    if rates_file_arg <> '' then Fail('--rates_file is given twice on the command line');
    rates_file_arg := AValue;
    Exit;
  end;
  for i := 0 to High(cmd_names) do
    if cmd_names[i] = AName then Fail('--' + AName + ' is given twice on the command line');
  n := Length(cmd_names);
  SetLength(cmd_names, n + 1);
  SetLength(cmd_values, n + 1);
  cmd_names[n] := AName;
  cmd_values[n] := AValue;
end;

procedure ReadNamedArguments;
var
  i, p: integer;
  arg, body: string;
begin
  for i := 1 to ParamCount do
  begin
    arg := ParamStr(i);
    if not AnsiStartsStr('--', arg) then
      Fail('Argument ' + IntToStr(i) + ' "' + arg + '" is not --name=value. Positional arguments ' +
           'are no longer supported; --help lists the settings (see model_settings.md)');
    body := Copy(arg, 3, MaxInt);
    if body = 'version' then begin PrintVersion; Halt(0); end;
    if body = 'help' then begin PrintHelp; Halt(0); end;
    p := Pos('=', body);
    if p = 0 then Fail('Argument "' + arg + '" has no value; use --name=value');
    if Copy(body, 1, p - 1) = 'settings' then
      Fail('--settings is not supported: put settings in the rates file, or override them as --name=value');
    AddCommandValue(Copy(body, 1, p - 1), Copy(body, p + 1, MaxInt));
  end;
end;

procedure LoadAllSettings;
var
  i: integer;
begin
  if ParamCount = 0 then
  begin
    PrintHelp;
    Fail('No arguments given');
  end;

  ReadNamedArguments;

  if rates_file_arg = '' then Fail('--rates_file is required');

  {2. the rates file, 3. the command line}
  ReadSettingsFile(ExpandFileName(rates_file_arg));
  for i := 0 to High(cmd_names) do
    SetSetting(cmd_names[i], cmd_values[i], 'command line');
end;


{---- checks and logging -----------------------------------------------------------------------}

procedure CheckSettings;
var
  i: integer;
  missing: string;
  tm1, tm2: longint;
begin
  missing := '';
  for i := 0 to High(Settings) do
    if Settings[i].Required and (Settings[i].Source = 'default') then
      missing := missing + ' ' + Settings[i].Name;
  if (habitat_folder = '0') and (mapname_rabbit = '') then
    missing := missing + ' mapname_rabbit (needed when habitat_folder = 0)';
  if missing <> '' then Fail('Missing setting(s):' + missing);

  if end_year < start_year then Fail('end_year is before start_year');
  if not ((R_young_age <= R_adult_age) and (R_adult_age <= R_old_age) and (R_old_age < R_max_age)) then
    Fail('Ages must satisfy young_age <= adult_age <= old_age < max_age');
  if R_MinLitSize > R_MaxLitSize then Fail('MinLitSize is larger than MaxLitSize');
  if RHDFreq_L > RHDFreq_U then Fail('RHDFreq_L is larger than RHDFreq_U');
  if RHDMort_L > RHDMort_U then Fail('RHDMort_L is larger than RHDMort_U');
  if RHD_init_immune_lo > RHD_init_immune_hi then Fail('RHD_init_immune_lo is larger than RHD_init_immune_hi');
  if (RHD2_mortality < 0) and (RHD2_mortality <> -1) then Fail('RHD2_mortality must be -1 or between 0 and 1');

  {Arrival dates (immunity mode): an arrival year of 0, or any date up to the start of the
   simulation, means the strain is present from the start (see SetupRHD)}
  if RHD_mode = RHD_MODE_IMMUNITY then
  begin
    if RHD1_arrival_year = 0 then tm1 := 0
    else tm1 := (RHD1_arrival_year - start_year) * 12 + RHD1_arrival_month;
    if RHD2_arrival_year = 0 then tm2 := 0
    else tm2 := (RHD2_arrival_year - start_year) * 12 + RHD2_arrival_month;
    if (RHD1_arrival_year > 0) and (tm1 <= 0) then
      WriteLn('Warning: RHD1_arrival is not after the start of the simulation, so RHDV1 is present from the start');
    if (RHD2_arrival_year > 0) and (tm2 <= 0) then
      WriteLn('Warning: RHD2_arrival is not after the start of the simulation, so RHDV2 is present from the start');
    if (tm1 > 0) and (tm2 <= tm1) then
      WriteLn('Warning: RHD1_arrival_year has no effect: RHDV2 is present ',
              IfThen(tm2 <= 0, 'from the start', 'before it'),
              '. Set RHD2_arrival_year to its arrival year, or 9999 = never.');
  end;
end;

procedure LogSettings;
var
  i: integer;
  F: TextFile;
  line: string;
begin
  for i := 0 to High(Settings) do
    with Settings[i] do
      if (Source = 'command line') or ((Source <> 'default') and (PrevSource <> 'default') and
                                       (PrevSource <> '')) then
      begin
        line := 'Setting ' + Name + ' = ' + ValueText(Settings[i]) + ' (' + Source;
        if (PrevSource <> '') and (PrevSource <> 'default') then
          line := line + '; was ' + PrevText + ' from ' + PrevSource;
        WriteLn(line + ')');
      end;
  WriteLn('RHD_mode = ', ValueText(Settings[FindSetting('RHD_mode')]), ', seed = ', seed);

  {Every setting, so that a run can be repeated with --rates_file=settings_used.txt}
  ForceDirectories(output_dir);
  AssignFile(F, IncludeTrailingPathDelimiter(output_dir) + 'settings_used.txt');
  Rewrite(F);
  WriteLn(F, '# Settings of this run (settings interface ', SETTINGS_INTERFACE, ').');
  WriteLn(F, '# Repeat it with --rates_file=<this file> --output_dir=<new folder>');
  for i := 0 to High(Settings) do
    with Settings[i] do
      if (Name <> 'output_dir') and (ValueText(Settings[i]) <> '') then
        WriteLn(F, Name, ' ', ValueText(Settings[i]), '   # ', Source);
  CloseFile(F);
end;

end.
