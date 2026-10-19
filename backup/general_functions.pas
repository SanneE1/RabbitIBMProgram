unit general_functions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Dialogs,
  general_define_units;

function randomPoisson(mean: real): integer;
procedure ArrayToNegOne(var arr: array of integer);
function ReadMap(mapName: string): Array2Dinteger;
procedure OpenKMapFile(fileName: string);
function ReadKMap(year, month: integer): Array2Dinteger;
procedure ShowErrorAndExit(const errMsg: string);


implementation

function randomPoisson(mean: real): integer;
  {pseudorandom Poisson distributed number genetrator, Donald Knuth's algorithm}
const
  RESOLUTION = 1000;
var
  k: integer;
  b, l: real;
begin
  //assert(mean > 0, 'mean < 1');
  k := 0;
  b := 1;
  l := exp(-mean);
  while b > l do
  begin
    k := k + 1;
    b := b * random(RESOLUTION) / RESOLUTION;
  end;
  if mean <= 0 then randomPoisson := 0
  else
    randomPoisson := k - 1;
end;

procedure ArrayToNegOne(var arr: array of integer);
var
  i: integer;
begin
  for i := Low(arr) to High(arr) do
    arr[i] := -1;
end;

function ReadMap(mapName: string): Array2Dinteger;
var
  ix, iy, Value: integer;
  mapX, mapY: integer;
begin

  {Read in map}
  Assign(filename, mapName);
  reset(filename);

  readln(filename, mapX, mapY);

  if MapDimX = 0 then
  begin
    MapDimX := mapX;
    MapDimY := mapY;
  end
  else
  if (MapDimX <> mapX) or (MapDimY <> mapY) then
    ShowErrorAndExit('The current map file has different dimensions from the previous one(s). File: ' + mapName);

  SetLength(Result, Mapdimx + 1, Mapdimy + 1);

  for iy := 1 to Mapdimy do
  begin
    begin
      for ix := 1 to Mapdimx do
      begin
        Read(filename, Value);
        // HabitatMap (and the others) are 'byte' types which is less memory
        // intensive than an integer, but that does mean it can only deal with 0:255
        // There are values in the map of -9999 that represent the sea. As its the same as a barrier, here set to 0!
        if Value < 0 then Result[ix, iy] := 0
        else
          Result[ix, iy] := Value;
      end;
    end;
    readln(filename);
  end;
  Close(filename);

end;

{Binary file with the carrying capacity maps of consecutive months, written by write_K_binary() in
 rabbit/functions/K_map_binary.R. Header (little endian): 'KMAP', then int32 version, ncol, nrow,
 n_months, first_year, first_month, bytes per value (1 or 2); then one nrow*ncol block per month
 (top row first, x fastest). Reads only the header here; ReadKMap reads one month at a time.}
procedure OpenKMapFile(fileName: string);
var
  fs: TFileStream;
  magic: array[0..3] of char;
  hdr: array[0..6] of longint;
begin
  fs := TFileStream.Create(fileName, fmOpenRead or fmShareDenyNone);
  try
    fs.ReadBuffer(magic, 4);
    if magic <> 'KMAP' then ShowErrorAndExit('Not a K map file (missing KMAP header): ' + fileName);
    fs.ReadBuffer(hdr, SizeOf(hdr));
  finally
    fs.Free;
  end;

  if hdr[0] <> 1 then ShowErrorAndExit('Unsupported K map file version ' + IntToStr(hdr[0]) + ': ' + fileName);
  if (hdr[6] <> 1) and (hdr[6] <> 2) then ShowErrorAndExit('K map file must have 1 or 2 bytes per value: ' + fileName);

  kmap_file := fileName;
  kmap_ncol := hdr[1];
  kmap_nrow := hdr[2];
  kmap_nmonths := hdr[3];
  kmap_first_year := hdr[4];
  kmap_first_month := hdr[5];
  kmap_bytes := hdr[6];

  if MapDimX = 0 then
  begin
    MapDimX := kmap_ncol;
    MapDimY := kmap_nrow;
  end
  else if (MapDimX <> kmap_ncol) or (MapDimY <> kmap_nrow) then
    ShowErrorAndExit('The K map file has different dimensions from the previous map(s). File: ' + fileName);
end;

function ReadKMap(year, month: integer): Array2Dinteger;
var
  fs: TFileStream;
  idx, ix, iy: integer;
  buf8: array of byte;
  buf16: array of word;
  blocksize: int64;
begin
  idx := (year - kmap_first_year) * 12 + (month - kmap_first_month);
  if idx < 0 then
    ShowErrorAndExit('K map file starts after the requested month: ' + IntToStr(year) + '-' + IntToStr(month));
  {Months after the last stored month reuse the last one}
  if idx >= kmap_nmonths then idx := kmap_nmonths - 1;

  SetLength(Result, Mapdimx + 1, Mapdimy + 1);
  blocksize := int64(kmap_ncol) * kmap_nrow;

  fs := TFileStream.Create(kmap_file, fmOpenRead or fmShareDenyNone);
  try
    fs.Position := 32 + int64(idx) * blocksize * kmap_bytes;
    if kmap_bytes = 1 then
    begin
      SetLength(buf8, blocksize);
      fs.ReadBuffer(buf8[0], blocksize);
      for iy := 1 to Mapdimy do
        for ix := 1 to Mapdimx do
          Result[ix, iy] := buf8[(iy - 1) * Mapdimx + (ix - 1)];
    end
    else
    begin
      SetLength(buf16, blocksize);
      fs.ReadBuffer(buf16[0], blocksize * 2);
      for iy := 1 to Mapdimy do
        for ix := 1 to Mapdimx do
          Result[ix, iy] := buf16[(iy - 1) * Mapdimx + (ix - 1)];
    end;
  finally
    fs.Free;
  end;
end;

procedure ShowErrorAndExit(const errMsg: string);
begin
  {$IFDEF LCL}
  // If in GUI mode, use MessageDlg for graphical error display
  MessageDlg('Error: ' + errMsg, mtError, [mbOK], 0);
  {$ELSE}
  // In non-GUI mode, use console output
  Writeln('Error: ', errMsg);
  Readln;
  {$ENDIF}

  Halt(1);  // Exit the program with a non-zero code to indicate error
end;


end.

