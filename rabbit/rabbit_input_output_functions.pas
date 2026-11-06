unit rabbit_input_output_functions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  general_functions, general_define_units;

procedure ReadClim;
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

