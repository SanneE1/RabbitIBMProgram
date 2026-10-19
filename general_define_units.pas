unit general_define_units;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type           {here you declare the data structure for you individuals}
  Array2DInteger = array of array of integer;
  Array3DInteger = array of array of array of integer;

  MapOfLists = array of array of Tlist;

  PRabbit = ^RabbitAgent;

  RabbitAgent = record
    sex: string[1];
    Age: integer;      // months
    Pregnant: boolean;  // Individual pregnant?
    Lactating: boolean;
    LastDispersalMonth: longint;  // tot_m of the month this rabbit last dispersed (0 = never)
  end;


 TRHDCellData = record
    NextOutbreakMonth: Integer;      // When next outbreak occurs
    OutbreakFrequency: Integer;      // 24-36 months between outbreaks
    OutbreakMortality: Real;         // 0.15-0.25 mortality rate
  end;



var
  {Simulation info}
  current_year, n_years, start_year, end_year, month: integer;
  output_dir, habitat_folder: string;
  create_maps_3month_maps: boolean = False;
  create_2yr_month_maps: boolean = False;
  rabbit_census_maps: boolean = True;
  create_all_month_maps: boolean = False;

  {General variables}
  Mapdimx, Mapdimy: integer;
  filename: Text;
  xp, yp: integer;

  {Rabbit - population info}
  RabbitPopulationSpatial: MapOfLists;
  HabitatMapRabbit: Array2Dinteger;
  paramname_rabbit: string;
  rabbit_start_file: string;

  {Carrying capacity maps of all months in one binary file (see ReadKMap)}
  kmap_file: string = '';
  kmap_ncol, kmap_nrow, kmap_nmonths, kmap_first_year, kmap_first_month, kmap_bytes: longint;

  {Rabbit - Climate effects}
  BreedingMonths_xy: Array3DInteger;
  DryMonths_xy: Array3DInteger;
  mapname_rabbit, breedname, dryname, climate_folder: string;

  {Rabbit - Disease mechanism}
  RHDFreq_L, RHDFreq_U: integer;
  RHDMort_L, RHDMort_U: real;
  RHDData: array of array of TRHDCellData;
  tot_m: longint;

  {Rabbit - Demography}
  R_lambda, R_dens_opt, R_sigma: real;                            // Dispersal parameters
  R_max_age, R_young_age, R_adult_age, R_old_age: integer;      // Ages in months
  R_disp_age: integer;
  R_MeanLitSize, R_SdLitSize: real;
  R_r_int, R_r_dens_effect, R_r_second_effect, R_r_later_effect: real;
  R_MortP_at_month_old, R_s_int, R_s_extra_juv, R_s_food_effect, R_s_dens_effect: real;

  {Missceleneous // or however you spell that}
   a, i, b, taskID:integer;
   output_maps: string;


const
  disp_x: array[0..48] of integer = (-3, -2, -1, 0, 1, 2, 3,
                                       -3, -2, -1, 0, 1, 2, 3,
                                       -3, -2, -1, 0, 1, 2, 3,
                                       -3, -2, -1, 0, 1, 2, 3,
                                       -3, -2, -1, 0, 1, 2, 3,
                                       -3, -2, -1, 0, 1, 2, 3,
                                       -3, -2, -1, 0, 1, 2, 3);
    disp_y: array[0..48] of integer = (3, 3, 3, 3, 3, 3, 3,
                                       2, 2, 2, 2, 2, 2, 2,
                                       1, 1, 1, 1, 1, 1, 1,
                                       0, 0, 0, 0, 0, 0, 0,
                                      -1, -1, -1, -1, -1, -1, -1,
                                      -2, -2, -2, -2, -2, -2, -2,
                                      -3, -3, -3, -3, -3, -3, -3);
    disp_dist: array[0..48] of integer = (3, 3, 3, 3, 3, 3, 3,
                                          3, 2, 2, 2, 2, 2, 3,
                                          3, 2, 1, 1, 1, 2, 3,
                                          3, 2, 1, 0, 1, 2, 3,
                                          3, 2, 1, 1, 1, 2, 3,
                                          3, 2, 2, 2, 2, 2, 3,
                                          3, 3, 3, 3, 3, 3, 3);

implementation


end.

