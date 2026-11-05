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
    Immune: boolean;              // RHD immunity (RHD_mode = immunity)
    InfectedMonth: longint;       // tot_m of the month this rabbit was infected with RHD (0 = never)
  end;


 TRHDCellData = record
    {RHD_mode = schedule}
    NextOutbreakMonth: Integer;      // When next outbreak occurs
    OutbreakFrequency: Integer;      // 24-36 months between outbreaks
    OutbreakMortality: Real;         // 0.15-0.25 mortality rate
    {RHD_mode = immunity}
    Exposed: boolean;                // virus reached the cell (seeded, or by an infected disperser)
    OutbreakThisMonth: boolean;
    OutbreakLastMonth: boolean;
    NOutbreaks: integer;
  end;



const
  {RHD_mode values}
  RHD_MODE_NONE = 0;
  RHD_MODE_SCHEDULE = 1;
  RHD_MODE_IMMUNITY = 2;

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

  {Rabbit - Disease mechanism, read from the RHD settings file (command line argument 14).
   See rabbit_input_output_functions.ReadParameters_RHD and docs/model_settings.md}
  rhd_settings_file: string = '0';
  RHD_mode: integer = RHD_MODE_SCHEDULE;
  RHD_min_age: integer = 3;          // minimum age (months, before this month's ageing) to be susceptible
  RHD_f_crit: real = 0.5;            // susceptible share at which an exposed cell has a 50% outbreak chance
  RHD_f_slope: real = 20;            // steepness of the outbreak probability around RHD_f_crit
  RHD_spark: real = 0.0;             // background introduction, probability per cell per month
  RHD_spread: real = 0.0;            // probability per neighbouring cell with an outbreak last month
  RHD_mortality: real = 0.6;         // share of infected rabbits that die
  RHD2_mortality: real = -1;         // same for RHDV2; < 0 means use RHD_mortality
  RHD1_arrival_year: integer = 0;    // 0 = arrived before the simulation starts
  RHD1_arrival_month: integer = 1;
  RHD2_arrival_year: integer = 0;    // 0 = arrived before the simulation starts; 9999 = never
  RHD2_arrival_month: integer = 1;
  RHD_seed_share: real = 0.05;       // share of occupied cells exposed at an arrival
  RHD2_cross_immunity: real = 0.0;   // chance that RHDV1 immunity protects against RHDV2
  RHD_init_immune_lo: real = 0.2;    // range of the immune share per cell for runs starting after arrival
  RHD_init_immune_hi: real = 0.8;
  RHD_log: boolean = True;           // write rhd_outbreaks.csv and rhd_monthly.csv
  RHD_strain: integer = 0;           // current strain: 0 = no disease yet, 1 = RHDV1, 2 = RHDV2
  RHD1_arrival_tm, RHD2_arrival_tm: longint;  // arrival as tot_m (<= 0: before the simulation)
  RHD_deaths_month: longint;
  RHDOutbreakFile, RHDMonthlyFile: TextFile;

  {Rabbit - Demography}
  R_lambda, R_dens_opt, R_sigma: real;                            // Dispersal parameters
  R_max_age, R_young_age, R_adult_age, R_old_age: integer;      // Ages in months
  R_disp_age: integer;
  R_MeanLitSize, R_SdLitSize: real;                            // R_SdLitSize: no longer used
  R_MinLitSize: integer = 1;                                    // litter size limits (kits)
  R_MaxLitSize: integer = 9;
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

