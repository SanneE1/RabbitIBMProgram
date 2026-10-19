unit rabbit_vital_rates;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, math,
  general_define_units, general_functions;


procedure Reproduction(Pop: TList; local_breeding_conditions: integer; Kdens: real);
procedure Survival(Pop: TList; Kdens: real; dry_months: integer);
procedure Dispersal;
procedure ApplyRHD(Pop: TList; x, y, tot_m: Integer);

implementation


function NewRabbit(AgeMonths: integer; IsFemale: boolean): PRabbit;
begin
  New(Result);
  Result^.Age := AgeMonths;
  if IsFemale then Result^.Sex := 'f' else Result^.Sex := 'm';
  Result^.Pregnant := False;
  Result^.Lactating := False;
  Result^.LastDispersalMonth := 0;
end;


procedure Reproduction(Pop: TList; local_breeding_conditions: integer; Kdens: real);
var
  a, j, k, minlitsize, maxlitsize, n_litters, n: integer;
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

  minlitsize := Round(R_MeanLitSize - 2 * R_SdLitSize);
  maxlitsize := Round(R_MeanLitSize + 2 * R_SdLitSize);

  for n := 1 to n_litters do
  begin
    k := randomPoisson(R_MeanLitSize);
    if k < minlitsize then k := minlitsize;
    if k > maxlitsize then k := maxlitsize;

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

end.
