unit rabbit_population_dynamics;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  rabbit_input_output_functions, rabbit_vital_rates,
  general_functions, general_define_units;

procedure Startpopulation_rabbit;
procedure SetupRHD;
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
      Rabbit^.Immune := False;
      Rabbit^.InfectedMonth := 0;

      RabbitPopulationSpatial[x][y].Add(Rabbit);
    end;
  end;
end;

{Disease state at the start of the simulation, after the start population is made}
procedure SetupRHD;
var
  x, y, b: integer;
  u: real;
  Pop: TList;
  Rabbit: PRabbit;
begin
  tot_m := 0;
  SetLength(RHDData, MapdimX + 1, MapdimY + 1);

  {All cells, also those without habitat in the first month: before, cells that only became habitat
   later had a mortality of 0 and so never had an outbreak}
  if RHD_mode = RHD_MODE_SCHEDULE then
    for x := 1 to MapdimX do
      for y := 1 to MapdimY do
      begin
        RHDData[x,y].OutbreakFrequency := RHDFreq_L + Random(RHDFreq_U - RHDFreq_L + 1);  // Random frequency: 24-36 months (2-3 years)
        RHDData[x,y].OutbreakMortality := RHDMort_L + Random * (RHDMort_U - RHDMort_L);   // Random severity: 15-25% mortality
        RHDData[x,y].NextOutbreakMonth := Random(RHDData[x,y].OutbreakFrequency);         // Random initial timing (stagger outbreaks across cells)
      end;

  if RHD_mode <> RHD_MODE_IMMUNITY then Exit;

  {Arrival dates as tot_m (1 = January of the start year); year 0 = before the simulation}
  if RHD1_arrival_year = 0 then RHD1_arrival_tm := 0
  else RHD1_arrival_tm := (RHD1_arrival_year - start_year) * 12 + RHD1_arrival_month;
  if RHD2_arrival_year = 0 then RHD2_arrival_tm := 0
  else RHD2_arrival_tm := (RHD2_arrival_year - start_year) * 12 + RHD2_arrival_month;

  RHD_strain := 0;
  if RHD1_arrival_tm <= 0 then RHD_strain := 1;
  if RHD2_arrival_tm <= 0 then RHD_strain := 2;
  WriteLn('RHD: immunity mode, strain at the start = ' + IntToStr(RHD_strain));

  {Started after an arrival: the disease is already around, so part of the rabbits are immune.
   The immune share differs per cell, so that cells are not all in the same phase.}
  if RHD_strain > 0 then
    for x := 1 to MapdimX do
      for y := 1 to MapdimY do
      begin
        Pop := RabbitPopulationSpatial[x, y];
        if (Pop = nil) or (Pop.Count = 0) then Continue;
        u := RHD_init_immune_lo + random * (RHD_init_immune_hi - RHD_init_immune_lo);
        for b := 0 to Pop.Count - 1 do
        begin
          Rabbit := PRabbit(Pop.Items[b]);
          if (Rabbit^.Age >= RHD_min_age) and (random < u) then Rabbit^.Immune := True;
        end;
      end;

  if RHD_log then OpenRHDLogs;
end;

{RHD_mode = immunity: arrivals, seeding, and moving the outbreak flags on by one month}
procedure RHDMonthStart;
var
  x, y, b: integer;
  arrival: boolean;
  Pop: TList;
begin
  RHD_deaths_month := 0;

  for x := 1 to MapdimX do
    for y := 1 to MapdimY do
    begin
      RHDData[x, y].OutbreakLastMonth := RHDData[x, y].OutbreakThisMonth;
      RHDData[x, y].OutbreakThisMonth := False;
    end;

  arrival := False;
  if (RHD1_arrival_tm > 0) and (tot_m = RHD1_arrival_tm) then
  begin
    RHD_strain := 1;
    arrival := True;
    WriteLn('RHD: RHDV1 arrives');
  end;

  if (RHD2_arrival_tm > 0) and (tot_m = RHD2_arrival_tm) then
  begin
    RHD_strain := 2;
    arrival := True;
    WriteLn('RHD: RHDV2 arrives');
    {RHDV1 immunity protects against RHDV2 with probability RHD2_cross_immunity}
    for x := 1 to MapdimX do
      for y := 1 to MapdimY do
      begin
        Pop := RabbitPopulationSpatial[x, y];
        if Pop = nil then Continue;
        for b := 0 to Pop.Count - 1 do
          if PRabbit(Pop.Items[b])^.Immune and (random >= RHD2_cross_immunity) then
            PRabbit(Pop.Items[b])^.Immune := False;
      end;
  end;

  if arrival then
    for x := 1 to MapdimX do
      for y := 1 to MapdimY do
      begin
        Pop := RabbitPopulationSpatial[x, y];
        if (Pop <> nil) and (Pop.Count > 0) and (random < RHD_seed_share) then
          RHDData[x, y].Exposed := True;
      end;
end;

procedure Rabbit_monthly_demography(current_year, m: integer);
var
  b, x, y: integer;
  Pop: TList;
  Kdens: real;
begin

  if RHD_mode = RHD_MODE_IMMUNITY then RHDMonthStart;

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

    if (RHD_mode = RHD_MODE_SCHEDULE) and (Pop.Count > 0) and (tot_m >= RHDData[x,y].NextOutbreakMonth) then
      ApplyRHD(Pop, x, y, tot_m)
    else if (RHD_mode = RHD_MODE_IMMUNITY) and (Pop.Count > 0) then
      RHDStep(Pop, x, y);

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

  if (RHD_mode = RHD_MODE_IMMUNITY) and RHD_log then WriteRHDMonthly;
end;

end.
