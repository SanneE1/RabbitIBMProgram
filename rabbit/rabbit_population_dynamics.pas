unit rabbit_population_dynamics;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  rabbit_input_output_functions, rabbit_vital_rates,
  general_functions, general_define_units;

procedure Startpopulation_rabbit;
procedure Rabbit_monthly_demography(current_year, m: integer);
//procedure RunPopSim;

implementation


procedure Startpopulation_rabbit;
var
  a, x, y, n_start: integer;
  StartMap: array of array of integer;
  Rabbit: PRabbit;
begin

  if (rabbit_start_file <> '0') then
    {Map of starting individuals per cell (same format as the other input maps)}
    StartMap := ReadMap(rabbit_start_file)
  else
    {Fall back to initialising from the carrying capacity map}
    StartMap := HabitatMapRabbit;

  SetLength(RabbitPopulationSpatial, Mapdimx + 1, Mapdimy + 1);

  for x := 1 to Mapdimx do
  for y := 1 to Mapdimy do
  begin

    if StartMap[x,y] = 0 then Continue;

    n_start := StartMap[x,y];

    RabbitPopulationSpatial[x][y] := TList.Create;

    for a := 1 to n_start do
    begin
      New(Rabbit);

      Rabbit^.Age := random(12);  //alternative: Age := 0;
      if random < 0.5 then
        Rabbit^.Sex := 'f'
      else
        Rabbit^.Sex := 'm';

      Rabbit^.Pregnant := False;
      Rabbit^.Lactating := False;
      Rabbit^.LastDispersalMonth := 0;

      RabbitPopulationSpatial[x][y].Add(Rabbit);
    end;
  end;
end;

procedure Rabbit_monthly_demography(current_year, m: integer);
var
  b, x, y: integer;
  Pop: TList;
  Kdens: real;
begin

  for x := 1 to MapdimX do
  for y := 1 to MapdimY do
  begin

    Pop := RabbitPopulationSpatial[x][y];

    if HabitatMapRabbit[x,y] = 0 then
    begin
      {Cell is (no longer) habitable: remove its rabbits}
      if Pop <> nil then
      begin
        for b := 0 to Pop.Count - 1 do
          Dispose(PRabbit(Pop.Items[b]));
        FreeAndNil(RabbitPopulationSpatial[x][y]);
      end;
      Continue;
    end;

    if (Length(DryMonths_xy[x,y]) = 0) or (Length(BreedingMonths_xy[x,y]) = 0) then
    begin
      WriteLn('Skipping cell with no climate data: month=', m, ' x=', x, ' y=', y);
      Continue;
    end;

    if Pop = nil then Continue;

    if (Pop.Count > 0) and (tot_m >= RHDData[x,y].NextOutbreakMonth) then
      ApplyRHD(Pop, x, y, tot_m);

    // Density as fraction of carrying capacity; the habitat map holds rabbits per 25 ha cell (500x500 m)
    Kdens := Pop.Count / HabitatMapRabbit[x,y];

    Reproduction(Pop, BreedingMonths_xy[x,y,m], Kdens);
    Survival(Pop, Kdens, DryMonths_xy[x,y,m]);   // Survival needs the density and the number of dry months

    {Aging}
    for b := 0 to Pop.Count - 1 do
      Inc(PRabbit(Pop.Items[b])^.Age);
  end;

  {With the whole spatial population, start distribution}
  Dispersal;
end;

end.
