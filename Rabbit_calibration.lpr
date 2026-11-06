program Rabbit_population_simulation;

{$mode objfpc}{$H+}


uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils,
  general_functions, general_define_units,
  rabbit_population_dynamics, rabbit_input_output_functions;

{$R *.res}
var
  LineSplit: TStringArray;
  settings_file, Line: string;
  x,y: integer;
  use_kmap_file: boolean;
  cli_dispersal: boolean = False;
  cli_dens_opt, cli_lambda, cli_sigma: real;

begin
  randomize; {initialize the pseudorandom number generator}

  output_dir := ParamStr(1);
  start_year := StrToInt(ParamStr(2));
  end_year := StrToInt(ParamStr(3));
  paramname_rabbit := ParamStr(4);
  mapname_rabbit := ParamStr(5);
  habitat_folder := ParamStr(6);
  climate_folder := ParamStr(7);

  if (ParamStr(8) = '1') then
      create_all_month_maps := True;

  {Argument 9: '0' = initialise from the carrying capacity map, otherwise the path to a start-population map}
  rabbit_start_file := ParamStr(9);

  {Dispersal parameters of the current run (arguments 10-12). They are applied after the parameter
   file is read, which also holds lambda, dens_opt and sigma; before, the file values overwrote
   these and the command line values had no effect.}
  if ParamCount > 9 then
  begin
   cli_dispersal := True;
   cli_dens_opt := StrToInt(ParamStr(10));
   Val(Trim(ParamStr(11)), cli_lambda);
   Val(Trim(ParamStr(12)), cli_sigma);
  end;

  {Optional argument 13: random seed, to make a run reproducible (-1 = no fixed seed)}
  if (ParamCount > 12) and (StrToInt(ParamStr(13)) <> -1) then
  begin
    RandSeed := StrToInt(ParamStr(13));
    WriteLn('Random seed = ' + IntToStr(RandSeed));
  end;

  {Optional argument 14: RHD settings file ('0' = none; see docs/model_settings.md)}
  if ParamCount > 13 then
    rhd_settings_file := ParamStr(14);


mapname_rabbit := ExpandFileName(mapname_rabbit);
climate_folder := ExpandFileName(climate_folder);

if not (habitat_folder = '0') then
  habitat_folder := ExpandFileName(habitat_folder);

if (rabbit_start_file <> '0') then
  rabbit_start_file := ExpandFileName(rabbit_start_file);

WriteLn('start_year = ' + IntToStr(start_year));
WriteLn('end_year = ' + IntToStr(end_year));
WriteLn('create_maps_3month_maps = ' + create_maps_3month_maps.ToString(TUseBoolStrs.true));
WriteLn('create_2yr_month_maps = ' + create_2yr_month_maps.ToString(TUseBoolStrs.true));
WriteLn('rabbit_census_maps = ' + rabbit_census_maps.ToString(TUseBoolStrs.true));
WriteLn('mapname_rabbit = ' + mapname_rabbit);
WriteLn('climate_folder = ' + climate_folder);
WriteLn('habitat_folder = ' + habitat_folder);

n_years := (end_year - start_year) + 1;

WriteLn('Reading Rabbit parameters');
paramname_rabbit := ExpandFileName(paramname_rabbit);
ReadParameters_Rabbit(paramname_rabbit);

if cli_dispersal then
begin
  R_dens_opt := cli_dens_opt;
  R_lambda := cli_lambda;
  R_sigma := cli_sigma;
  WriteLn('Dispersal parameters from the command line: dens_opt=' + FloatToStr(R_dens_opt) +
          ', lambda=' + FloatToStr(R_lambda) + ', sigma=' + FloatToStr(R_sigma));
end;

if rhd_settings_file <> '0' then
begin
  rhd_settings_file := ExpandFileName(rhd_settings_file);
  WriteLn('Reading RHD settings: ' + rhd_settings_file);
  ReadParameters_RHD(rhd_settings_file);
end;



{Setting up the spatial and output variables}
WriteLn('Reading Maps');
MapDimX := 0;
MapDimY := 0;

{habitat_folder can be '0' (one static map), a folder with a text map per month (<year>_<month>.txt),
 or a single binary file with the maps of all months (see ReadKMap)}
use_kmap_file := (habitat_folder <> '0') and FileExists(habitat_folder) and not DirectoryExists(habitat_folder);

if use_kmap_file then
  begin
  WriteLn('K map file: ' + habitat_folder);
  OpenKMapFile(habitat_folder);
  HabitatMapRabbit := ReadKMap(start_year, 1);
  end
else if not (habitat_folder = '0') then
  begin
  WriteLn(habitat_folder + PathDelim + IntToStr(start_year) + '_01.txt');
  HabitatMapRabbit := ReadMap(habitat_folder + PathDelim + IntToStr(start_year) + '_01.txt')
  end
  else
  begin
  WriteLn(mapname_rabbit);
  HabitatMapRabbit := ReadMap(mapname_rabbit);
  end;

WriteLn('Creating output folders if they dont exist');
if not DirectoryExists(output_dir) then MkDir(output_dir);

output_maps := output_dir + PathDelim + 'maps';
if not DirectoryExists(output_maps) then MkDir(output_maps);

WriteLn('Start rabbit population');
Startpopulation_rabbit;

WriteLn('Set up disease objects');
SetupRHD;

WriteLn('Start simulation');

for current_year := start_year to end_year do
    begin

      WriteLn('Simulation Year ' + IntToStr(current_year));

      ReadClim;

      for month := 1 to 12 do
      begin
        tot_m := tot_m + 1;    // Keeping track of total months in simulation for disease outbreaks
        Rabbit_monthly_demography(current_year, month);

        if (rabbit_census_maps) and (((month = 3) or (month = 6) or (month = 9)) or ((current_year = 2017) or (current_year = 2018) or (current_year = 2023) or (current_year = 2024)))then
          WritePopsizeMap((output_dir + PathDelim + 'maps' + PathDelim + 'Rabbit_Population_distribution_' + IntToStr(current_year) + '_' + IntToStr(month) + '.csv'), RabbitPopulationSpatial, mapdimX, mapdimy);

        if create_maps_3month_maps and (month mod 3 = 0) then
          WritePopsizeMap((output_dir + PathDelim + 'maps' + PathDelim + 'Rabbit_Population_distribution_' + IntToStr(current_year) + '_' + IntToStr(month) + '.csv'), RabbitPopulationSpatial, mapdimX, mapdimy);

        if create_2yr_month_maps and (current_year >= end_year - 1) then
          WritePopsizeMap((output_dir + PathDelim + 'maps' + PathDelim + 'Rabbit_Population_distribution_' + IntToStr(current_year) + '_' + IntToStr(month) + '.csv'), RabbitPopulationSpatial, mapdimX, mapdimy);

        if create_all_month_maps then
          WritePopsizeMap((output_dir + PathDelim + 'maps' + PathDelim + 'Rabbit_Population_distribution_' + IntToStr(current_year) + '_' + IntToStr(month) + '.csv'), RabbitPopulationSpatial, mapdimX, mapdimy);

        if use_kmap_file then
          HabitatMapRabbit := ReadKMap(current_year, month)
        else if not (habitat_folder = '0') then
          if(month < 10) then HabitatMapRabbit := ReadMap(habitat_folder + PathDelim + IntToStr(current_year) + '_0' + IntToStr(month) + '.txt')
            else HabitatMapRabbit := ReadMap(habitat_folder + PathDelim + IntToStr(current_year) + '_' + IntToStr(month) + '.txt');

      end;
    end;


WriteLn('Simulation finished');

if (RHD_mode = RHD_MODE_IMMUNITY) and RHD_log then CloseRHDLogs;


for a := 0 to High(RabbitPopulationSpatial) do
  for b := 0 to High(RabbitPopulationSpatial[a]) do
    if RabbitPopulationSpatial[a, b] <> nil then
    begin
      for i := 0 to RabbitPopulationSpatial[a, b].Count - 1 do
        Dispose(PRabbit(RabbitPopulationSpatial[a, b].Items[i]));
      FreeAndNil(RabbitPopulationSpatial[a, b]);
    end;

end.


