unit rabbit_input_output_functions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  general_functions, general_define_units;

procedure ReadClim;
procedure ReadParameters_Rabbit(paramname: string);
procedure ReadParameters_RHD(paramname: string);
procedure OpenRHDLogs;
procedure CloseRHDLogs;
procedure WriteRHDOutbreak(x, y, n_age, n_susceptible, deaths: integer);
procedure WriteRHDMonthly;
procedure GetAbundanceMap(total_pop: MapOfLists; filename: string; year, month: integer);
procedure WritePopsizeMap(filename: string; var Poplist: MapOfLists; dimx, dimy: integer);
procedure WriteArrayToFile(const FileName: string; const arr: array of Integer);
function GetTotalSize(const population_list: MapOfLists): Integer;

implementation

procedure ReadClim;
var
 C: TextFile;
 Line, Parts: string;
 SplitParts: array of string;
 i, value, RowY, ColX: integer;

begin

SetLength(BreedingMonths_xy, Mapdimx + 1, Mapdimy + 1, 13);
SetLength(DryMonths_xy, Mapdimx + 1, Mapdimy + 1, 13);

//Assign(filename, breedname);
//reset(filename);

 breedname := ExpandFileName(climate_folder + PathDelim + 'breeding_months_' + IntToStr(current_year) + '.txt');

 //WriteLn('Reading Breeding months file: ' + breedname);

 AssignFile(C, breedname);
 Reset(C);
 
 while not EOF(C) do
  begin
    ReadLn(C, Line);

    SplitParts := Line.Split([' ']);
    if SplitParts[0] = 'col' then Continue;
    
    ColX := StrToInt(SplitParts[0]);
    RowY := StrToInt(SplitParts[1]);
    
    if (ColX > Mapdimx) or (RowY > Mapdimy) then
      ShowErrorAndExit('There are more columns/rows in the breeding month file than in the map. Map dim X/Y: ' + IntToStr(MapdimX) + '/' + IntToStr(MapdimY) + 'and file X/Y: ' + IntToStr(ColX) + '/' + IntToStr(RowY));
    
    SetLength(BreedingMonths_xy[ColX,RowY], 13);
    
    for i := 2 to 13 do
    begin
      if i > High(SplitParts) then Break;
      value := StrToInt(SplitParts[i]);
      BreedingMonths_xy[ColX][RowY][i - 1] := value;
    end;
  end;
  
  CloseFile(C);
  
 dryname := ExpandFileName(climate_folder + PathDelim + 'consecutive_dry_months_' + IntToStr(current_year) + '.txt');

 //WriteLn('Reading consecutive dry months file: ' + dryname);

 AssignFile(C, dryname);
 Reset(C);
 
 while not EOF(C) do
  begin
    ReadLn(C, Line);

    SplitParts := Line.Split([' ']);
    if SplitParts[0] = 'col' then Continue;
    
    ColX := StrToInt(SplitParts[0]);
    RowY := StrToInt(SplitParts[1]);
    
    if (ColX > Mapdimx) or (RowY > Mapdimy) then
      ShowErrorAndExit('There are more columns/rows in the Consecutive dry months file than in the map. Check your parameter file to make sure the map files and the climate files match in spatial scale');
    
    SetLength(DryMonths_xy[ColX,RowY], 13);
    
    for i := 2 to 13 do
    begin
      if i > High(SplitParts) then Break;
      value := StrToInt(SplitParts[i]);
      DryMonths_xy[ColX][RowY][i - 1] := value;
    end;
  end;
  
  CloseFile(C);

end;

procedure ReadParameters_Rabbit(paramname: string);
var
  LineSplit: TStringArray;
  Line: string;
  r, spacePos: integer;
  a, param: string;
  value: real;
begin

 Assign(filename, ExpandFileName(paramname));
  reset(filename);

  while not EOF(filename) do
  begin
    ReadLn(filename, Line);
    LineSplit := Line.Split(' ');

    if (LineSplit[0] = 'max_age') then R_max_age := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'young_age') then R_young_age := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'adult_age') then R_adult_age := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'old_age') then R_old_age := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'disp_age') then R_disp_age := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'MeanLitSize') then R_MeanLitSize := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'SdLitSize') then R_SdLitSize := StrToFloat(LineSplit[1])   // no longer used
    else if (LineSplit[0] = 'MinLitSize') then R_MinLitSize := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'MaxLitSize') then R_MaxLitSize := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'r_int') then R_r_int := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'r_dens_effect') then R_r_dens_effect := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'r_second_effect') then R_r_second_effect := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'r_later_effect') then R_r_later_effect := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'RHDFreq_L') then RHDFreq_L := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'RHDFreq_U') then RHDFreq_U := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'RHDMort_L') then RHDMort_L := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'RHDMort_U') then RHDMort_U := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'MortP_at_month_old') then R_MortP_at_month_old := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 's_int') then R_s_int := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 's_extra_juv') then R_s_extra_juv := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 's_dens_effect') then R_s_dens_effect := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 's_food_effect') then R_s_food_effect := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'lambda') then R_lambda := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'dens_opt') then R_dens_opt := StrToInt(LineSplit[1])
    else if (LineSplit[0] = 'sigma') then R_sigma := StrToFloat(LineSplit[1])
    else if (LineSplit[0] = 'mapname_rabbit') then mapname_rabbit := LineSplit[1]
    else if (LineSplit[0] = 'climate_folder') then climate_folder := LineSplit[1]
   end;

end;

{RHD settings file: one "key value" pair per line; empty lines and lines starting with # are skipped.
 Unknown keys stop the program, so that a typing error is not silently ignored.}
procedure ReadParameters_RHD(paramname: string);
var
  F: TextFile;
  LineSplit: TStringArray;
  Line, key, value: string;
  code: integer;

  function AsReal: real;
  begin
    Val(value, Result, code);
    if code <> 0 then ShowErrorAndExit('RHD settings: "' + value + '" is not a number (' + key + ')');
  end;

  function AsInt: integer;
  begin
    Val(value, Result, code);
    if code <> 0 then ShowErrorAndExit('RHD settings: "' + value + '" is not a whole number (' + key + ')');
  end;

begin
  AssignFile(F, ExpandFileName(paramname));
  Reset(F);

  while not EOF(F) do
  begin
    ReadLn(F, Line);
    Line := Trim(Line);
    if (Line = '') or (Line[1] = '#') then Continue;
    LineSplit := Line.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
    if Length(LineSplit) < 2 then ShowErrorAndExit('RHD settings: no value for "' + Line + '"');
    key := LineSplit[0];
    value := LineSplit[1];

    if key = 'RHD_mode' then
    begin
      if value = 'none' then RHD_mode := RHD_MODE_NONE
      else if value = 'schedule' then RHD_mode := RHD_MODE_SCHEDULE
      else if value = 'immunity' then RHD_mode := RHD_MODE_IMMUNITY
      else ShowErrorAndExit('RHD settings: RHD_mode must be none, schedule or immunity, not ' + value);
    end
    else if key = 'RHD_min_age' then RHD_min_age := AsInt
    else if key = 'RHD_f_crit' then RHD_f_crit := AsReal
    else if key = 'RHD_f_slope' then RHD_f_slope := AsReal
    else if key = 'RHD_spark' then RHD_spark := AsReal
    else if key = 'RHD_spread' then RHD_spread := AsReal
    else if key = 'RHD_mortality' then RHD_mortality := AsReal
    else if key = 'RHD2_mortality' then RHD2_mortality := AsReal
    else if key = 'RHD1_arrival_year' then RHD1_arrival_year := AsInt
    else if key = 'RHD1_arrival_month' then RHD1_arrival_month := AsInt
    else if key = 'RHD2_arrival_year' then RHD2_arrival_year := AsInt
    else if key = 'RHD2_arrival_month' then RHD2_arrival_month := AsInt
    else if key = 'RHD_seed_share' then RHD_seed_share := AsReal
    else if key = 'RHD2_cross_immunity' then RHD2_cross_immunity := AsReal
    else if key = 'RHD_init_immune_lo' then RHD_init_immune_lo := AsReal
    else if key = 'RHD_init_immune_hi' then RHD_init_immune_hi := AsReal
    else if key = 'RHD_log' then RHD_log := (value = '1') or (LowerCase(value) = 'true')
    {the settings of the schedule mode can also be given here}
    else if key = 'RHDFreq_L' then RHDFreq_L := AsInt
    else if key = 'RHDFreq_U' then RHDFreq_U := AsInt
    else if key = 'RHDMort_L' then RHDMort_L := AsReal
    else if key = 'RHDMort_U' then RHDMort_U := AsReal
    else ShowErrorAndExit('RHD settings: unknown setting "' + key + '"');
  end;

  CloseFile(F);
end;

procedure OpenRHDLogs;
begin
  AssignFile(RHDOutbreakFile, output_dir + PathDelim + 'rhd_outbreaks.csv');
  Rewrite(RHDOutbreakFile);
  WriteLn(RHDOutbreakFile, 'year,month,x,y,strain,n_age,n_susceptible,deaths');

  AssignFile(RHDMonthlyFile, output_dir + PathDelim + 'rhd_monthly.csv');
  Rewrite(RHDMonthlyFile);
  WriteLn(RHDMonthlyFile, 'year,month,strain,occupied_cells,outbreak_cells,rabbits,immune,rhd_deaths');
end;

procedure CloseRHDLogs;
begin
  CloseFile(RHDOutbreakFile);
  CloseFile(RHDMonthlyFile);
end;

procedure WriteRHDOutbreak(x, y, n_age, n_susceptible, deaths: integer);
begin
  WriteLn(RHDOutbreakFile, current_year, ',', month, ',', x, ',', y, ',', RHD_strain, ',',
          n_age, ',', n_susceptible, ',', deaths);
end;

{Called after dispersal, so the counts are the population at the end of the month}
procedure WriteRHDMonthly;
var
  x, y, b, occupied, outbreaks: integer;
  rabbits, immune: longint;
  Pop: TList;
begin
  occupied := 0; outbreaks := 0; rabbits := 0; immune := 0;
  for x := 1 to MapdimX do
    for y := 1 to MapdimY do
    begin
      if RHDData[x, y].OutbreakThisMonth then Inc(outbreaks);
      Pop := RabbitPopulationSpatial[x, y];
      if (Pop = nil) or (Pop.Count = 0) then Continue;
      Inc(occupied);
      rabbits := rabbits + Pop.Count;
      for b := 0 to Pop.Count - 1 do
        if PRabbit(Pop.Items[b])^.Immune then Inc(immune);
    end;
  WriteLn(RHDMonthlyFile, current_year, ',', month, ',', RHD_strain, ',', occupied, ',', outbreaks, ',',
          rabbits, ',', immune, ',', RHD_deaths_month);
end;

procedure GetAbundanceMap(total_pop: MapOfLists; filename: string; year, month: integer);
var
  csvFile: TextFile;
  temp_pop: TList;
  a, x, y: integer;
begin
  AssignFile(csvFile, filename);

  if (year = start_year) and (month = 1) then
    begin
    Rewrite(csvFile);
    // Write header
    WriteLn(csvFile, 'Year,Month,N_individuals');
    end
  else append(csvFile);

  a := 0;

  // Write data for each individual
  for x := 1 to MapdimX do
  for y := 1 to MapdimY do
  begin
    temp_pop := RabbitPopulationSpatial[x][y];

    if (temp_pop <> nil) then
     if (temp_pop.Count > 0) then
      a := a + temp_pop.Count;
  end;

  WriteLn(csvFile, year, ',', month, ',', a);

  CloseFile(csvFile);
end;


procedure WritePopsizeMap(filename: string; var Poplist: MapOfLists; dimx, dimy: integer);
var
  ix, iy, p: integer;
  outfile: Text;
begin
  Assign(outfile, filename);
  rewrite(outfile);

  // Loop over the arrayData and write each element to the CSV
  for iy := 1 to dimy do
  begin
    for ix := 1 to dimx do
    begin
     if Poplist[ix, iy] <> nil then p := Poplist[ix,iy].Count
     else p := 0;
      // Write each value, followed by a comma, except for the last value in the row
      if ix < dimx then
        Write(outfile, p, ',')
      else
        Write(outfile, p);  // No comma at the end of the row
    end;
    writeln(outfile);  // Move to the next line in the CSV file
  end;

  Close(outfile);
end;


function GetTotalSize(const population_list: MapOfLists): Integer;
var
  i, j: Integer;
  TotalCount: Integer;
begin
  TotalCount := 0;
  for i := 1 to High(population_list) do
    for j := 1 to High(population_list[i]) do
      if Assigned(population_list[i][j]) then
        TotalCount := TotalCount + population_list[i][j].Count;

  Result := TotalCount;
end;

procedure WriteArrayToFile(const FileName: string; const arr: array of Integer);
var
  FileStream: TFileStream;
  i: Integer;
  Line: string;
begin
  // Create or overwrite the file
  FileStream := TFileStream.Create(FileName, fmCreate);
  try
    for i := 0 to High(arr) do
    begin
      Line := IntToStr(arr[i]) + sLineBreak;  // Convert integer to string with newline
      FileStream.Write(Line[1], Length(Line)); // Write to file efficiently
    end;
  finally
    FileStream.Free; // Ensure the file is closed properly
  end;
end;


end.

