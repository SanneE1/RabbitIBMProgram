unit rabbit_vital_rates;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, math,
  general_define_units, general_functions, rabbit_input_output_functions;


procedure Reproduction(Pop: TList; local_breeding_conditions: integer; Kdens: real);
procedure Survival(Pop: TList; Kdens: real; dry_months: integer);
procedure Dispersal;
procedure ApplyRHD(Pop: TList; x, y, tot_m: Integer);
procedure RHDStep(Pop: TList; x, y: Integer);

implementation


function NewRabbit(AgeMonths: integer; IsFemale: boolean): PRabbit;
begin
  New(Result);
  Result^.Age := AgeMonths;
  if IsFemale then Result^.Sex := 'f' else Result^.Sex := 'm';
  Result^.Pregnant := False;
  Result^.Lactating := False;
  Result^.LastDispersalMonth := 0;
  Result^.Immune := False;
  Result^.InfectedMonth := 0;
end;


procedure Reproduction(Pop: TList; local_breeding_conditions: integer; Kdens: real);
var
  a, j, k, n_litters, n: integer;
  rep_p, surv_nb: real;
  Rabbit: PRabbit;

begin
  surv_nb := 1 - R_MortP_at_month_old; // newborn survival probability
  n_litters := 0;

  if Pop.Count <= 1 then Exit;

  // Only the rabbits present at the start of the month are checked, newborns are added afterwards
  for a := 0 to Pop.Count - 1 do
  begin
    Rabbit := PRabbit(Pop.Items[a]);

    if Rabbit^.Sex = 'f' then
    begin
      {If Rabbit has been lactating the last month; calculate nr of pups and add to population}
      if Rabbit^.Lactating then
      begin
        n_litters := n_litters + 1;   // Pups are created after this loop so the checks below only see adults
        Rabbit^.Lactating := False;
      end;

      if Rabbit^.Pregnant then
      begin
        Rabbit^.Pregnant := False;
        Rabbit^.Lactating := True;
      end
      else if (local_breeding_conditions = 1) and (Rabbit^.Age >= R_young_age) then
      begin
        {If not pregnant, determine if it happens now}
        if Rabbit^.Age < R_adult_age then
          rep_p := exp(R_r_int - R_r_dens_effect * Kdens) /
                   (1 + exp(R_r_int - R_r_dens_effect * Kdens))
        else if Rabbit^.Age < R_old_age then
          rep_p := exp(R_r_int + R_r_second_effect - R_r_dens_effect * Kdens) /
                   (1 + exp(R_r_int + R_r_second_effect - R_r_dens_effect * Kdens))
        else
          rep_p := exp(R_r_int + R_r_later_effect - R_r_dens_effect * Kdens) /
                   (1 + exp(R_r_int + R_r_later_effect - R_r_dens_effect * Kdens));

        if random < rep_p then
          Rabbit^.Pregnant := True;
      end;
    end;
  end;

  {Litter size: shifted Poisson, 1 + Poisson(MeanLitSize - 1), so every litter has at least one kit
   and the mean is MeanLitSize (variance MeanLitSize - 1); limited to MinLitSize..MaxLitSize.}
  for n := 1 to n_litters do
  begin
    k := 1 + randomPoisson(R_MeanLitSize - 1);
    if k < R_MinLitSize then k := R_MinLitSize;
    if k > R_MaxLitSize then k := R_MaxLitSize;

    for j := 1 to k do   // litter size
      if random < surv_nb then  // If they survived the first month while dependent on mother
        Pop.Add(NewRabbit(1, random < 0.5));
  end;
end;


procedure Survival(Pop: TList; Kdens: real; dry_months: integer);
var
  a: integer;
  surv_juv, surv_adult, surv_p: real;
  Rabbit: PRabbit;

begin
  {Calculate current survival probabilities as a function of density}
  surv_juv := (exp(R_s_int - R_s_extra_juv - R_s_dens_effect * Kdens) /
              (1 + exp(R_s_int - R_s_extra_juv - R_s_dens_effect * Kdens))) *
              (1 - exp(-R_s_food_effect / (dry_months + 0.001)));

  surv_adult := (exp(R_s_int - R_s_dens_effect * Kdens) /
                (1 + exp(R_s_int - R_s_dens_effect * Kdens))) *
                (1 - exp(-R_s_food_effect / (dry_months + 0.001)));

  {Determine survival of Rabbits; going down so deleting does not shift the remaining indices}
  for a := Pop.Count - 1 downto 0 do
  begin
    Rabbit := PRabbit(Pop.Items[a]);

    if Rabbit^.Age < R_young_age then surv_p := surv_juv
    else surv_p := surv_adult;

    if (Rabbit^.Age >= R_max_age) or (random > surv_p) then
    begin
      Dispose(Rabbit);
      Pop.Delete(a);
    end;
  end;
end;


procedure Dispersal;
var
  iy, ix, b, c, tx, ty: integer;
  p_not_stand, p_cumsum: array[0..48] of double;
  p_total, p_sum, p_disp: double;
  dens: integer;
  Pop: TList;
  Rabbit: PRabbit;

begin
  // Loop over the spatial population and find out how many Rabbits are dispersing
  for iy := 1 to MapdimY do
    for ix := 1 to MapdimX do
    begin
      Pop := RabbitPopulationSpatial[ix, iy];
      if (Pop = nil) or (HabitatMapRabbit[ix, iy] = 0) then Continue;

      p_total := 0;

      for c := 0 to High(disp_x) do
      begin
        tx := ix + disp_x[c];
        ty := iy + disp_y[c];
        if (tx < 1) or (ty < 1) or (tx > MapDimX) or (ty > MapDimY) or
           (HabitatMapRabbit[tx, ty] = 0) then
          p_not_stand[c] := 0
        else
        begin
          if RabbitPopulationSpatial[tx, ty] = nil then dens := 0
          else dens := RabbitPopulationSpatial[tx, ty].Count;
          p_not_stand[c] := exp(-R_lambda * Power((dens - R_dens_opt), 2)) /
                            (1 + Power(disp_dist[c], R_sigma));
        end;
        p_total := p_total + p_not_stand[c];
      end;

      if p_total = 0 then Continue;

      p_sum := 0;
      for c := 0 to High(disp_x) do
      begin
        p_sum := p_sum + p_not_stand[c] / p_total;
        p_cumsum[c] := p_sum;
      end;

      for b := Pop.Count - 1 downto 0 do
      begin
        Rabbit := PRabbit(Pop.Items[b]);

        // A rabbit that already arrived here from another cell this month does not move again
        if (Rabbit^.Age <> R_disp_age) or (Rabbit^.LastDispersalMonth = tot_m) then Continue;

        p_disp := random;

        // Pick the first cell whose cumulative probability exceeds the draw. Cells with
        // zero weight cannot be picked since they do not raise the cumulative sum.
        // If rounding leaves the draw above the final cumulative sum, the rabbit stays.
        for c := 0 to High(disp_x) do
          if p_disp < p_cumsum[c] then
          begin
            tx := ix + disp_x[c];
            ty := iy + disp_y[c];

            if (tx <> ix) or (ty <> iy) then
            begin
              Pop.Delete(b);
              if RabbitPopulationSpatial[tx, ty] = nil then
                RabbitPopulationSpatial[tx, ty] := TList.Create;
              RabbitPopulationSpatial[tx, ty].Add(Rabbit);

              // A rabbit infected with RHD this month takes the virus to its new cell (next month)
              if (RHD_mode = RHD_MODE_IMMUNITY) and (Rabbit^.InfectedMonth = tot_m) then
                RHDData[tx, ty].Exposed := True;
            end;
            Rabbit^.LastDispersalMonth := tot_m;
            Break;
          end;
      end;
    end;
end;


procedure ApplyRHD(Pop: TList; x, y, tot_m: Integer);
var
  a: Integer;
  Rabbit: PRabbit;

begin
  for a := Pop.Count - 1 downto 0 do
  begin
    Rabbit := PRabbit(Pop.Items[a]);

    // Apply RHD mortality only to (sub)adults
    if Rabbit^.Age > R_adult_age then
      if random < RHDData[x, y].OutbreakMortality then    // Mortality rates, not survival so < is needed
      begin
        Dispose(Rabbit);
        Pop.Delete(a);
      end;
  end;

  // Schedule next outbreak
  RHDData[x, y].NextOutbreakMonth := tot_m + RHDData[x, y].OutbreakFrequency;
end;


{RHD_mode = immunity, once per occupied cell per month (before reproduction and survival).
 1. Exposure: the virus reached the cell (seeded at an arrival, or brought by an infected disperser
    last month), or arrives by background introduction (RHD_spark), or from a neighbouring cell
    that had an outbreak last month (RHD_spread per such neighbour).
 2. Outbreak: with probability 1 / (1 + exp(-RHD_f_slope * (f - RHD_f_crit))), where f is the share
    of susceptible (non-immune) rabbits among those of at least RHD_min_age months.
 3. Each susceptible rabbit is infected; it dies with the mortality of the current strain, otherwise
    it becomes immune.}
procedure RHDStep(Pop: TList; x, y: Integer);
var
  a, c, nx, ny, n_age, n_susc, deaths: Integer;
  exposed: boolean;
  f, p_outbreak, mortality: real;
  Rabbit: PRabbit;
begin
  if RHD_strain = 0 then Exit;

  exposed := RHDData[x, y].Exposed;
  RHDData[x, y].Exposed := False;

  if (not exposed) and (RHD_spark > 0) and (random < RHD_spark) then exposed := True;

  if (not exposed) and (RHD_spread > 0) then
    for c := 0 to High(disp_x) do
      if disp_dist[c] = 1 then
      begin
        nx := x + disp_x[c];
        ny := y + disp_y[c];
        if (nx < 1) or (ny < 1) or (nx > MapdimX) or (ny > MapdimY) then Continue;
        if RHDData[nx, ny].OutbreakLastMonth and (random < RHD_spread) then
        begin
          exposed := True;
          Break;
        end;
      end;

  if not exposed then Exit;

  n_age := 0;
  n_susc := 0;
  for a := 0 to Pop.Count - 1 do
  begin
    Rabbit := PRabbit(Pop.Items[a]);
    if Rabbit^.Age >= RHD_min_age then
    begin
      Inc(n_age);
      if not Rabbit^.Immune then Inc(n_susc);
    end;
  end;
  if n_susc = 0 then Exit;

  f := n_susc / n_age;
  p_outbreak := 1 / (1 + exp(-RHD_f_slope * (f - RHD_f_crit)));
  if random >= p_outbreak then Exit;

  if (RHD_strain = 2) and (RHD2_mortality >= 0) then mortality := RHD2_mortality
  else mortality := RHD_mortality;

  deaths := 0;
  for a := Pop.Count - 1 downto 0 do
  begin
    Rabbit := PRabbit(Pop.Items[a]);
    if (Rabbit^.Age < RHD_min_age) or Rabbit^.Immune then Continue;

    Rabbit^.InfectedMonth := tot_m;
    if random < mortality then
    begin
      Dispose(Rabbit);
      Pop.Delete(a);
      Inc(deaths);
    end
    else
      Rabbit^.Immune := True;
  end;

  RHDData[x, y].OutbreakThisMonth := True;
  Inc(RHDData[x, y].NOutbreaks);
  RHD_deaths_month := RHD_deaths_month + deaths;
  if RHD_log then WriteRHDOutbreak(x, y, n_age, n_susc, deaths);
end;

end.
