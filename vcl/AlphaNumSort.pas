unit AlphaNumSort;

(*
 * The Alphanum Algorithm is an improved sorting algorithm for strings
 * containing numbers.  Instead of sorting numbers in ASCII order like
 * a standard sort, this algorithm sorts numbers in numeric order.
 *
 * The Alphanum Algorithm is discussed at http://www.DaveKoelle.com
 *
 * Translated from Java to Delphi by Daniel Marschall, www.daniel-marschall.de
 * Revision 2015-09-30
 *
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 *)

interface

uses
  SysUtils;

function AlphaNumCompare(s1, s2: string): integer;

implementation

function isDigit(ch: char): boolean;
begin
  result := (ord(ch) >= 48) and (ord(ch) <= 57);
end;

// Length of string is passed in for improved efficiency (only need to calculate it once)
function getChunk(s: string; slength, marker: integer): string;
var
  chunk: string;
  c: char;
begin
  c := s[marker+1];
  chunk := chunk + c;
  Inc(marker);
  if isDigit(c) then
  begin
    while marker < slength do
    begin
      c := s[marker+1];
      if not isDigit(c) then break;
      chunk := chunk + c;
      Inc(marker);
    end;
  end
  else
  begin
    while marker < slength do
    begin
      c := s[marker+1];
      if (isDigit(c)) then break;
      chunk := chunk + c;
      Inc(marker);
    end;
  end;
  result := chunk;
end;

function AlphaNumCompare(s1, s2: string): integer;
var
  s1Length, s2Length, thisChunkLength: integer;
  thisMarker, thatMarker, i: integer;
  thisChunk, thatChunk: string;
begin
  thisMarker := 0;
  thatMarker := 0;
  s1Length := Length(s1);
  s2Length := Length(s2);

  while (thisMarker < s1Length) and (thatMarker < s2Length) do
  begin
    thisChunk := getChunk(s1, s1Length, thisMarker);
    Inc(thisMarker, Length(thisChunk));

    thatChunk := getChunk(s2, s2Length, thatMarker);
    Inc(thatMarker, Length(thatChunk));

    // If both chunks contain numeric characters, sort them numerically
    if isDigit(thisChunk[1]) and isDigit(thatChunk[1]) then
    begin
      // Simple chunk comparison by length.
      thisChunkLength := Length(thisChunk);
      result := thisChunkLength - Length(thatChunk);
      // If equal, the first different number counts
      if result = 0 then
      begin
        for i := 0 to thisChunkLength-1 do
        begin
          result := ord(thisChunk[i+1]) - ord(thatChunk[i+1]);
          if result <> 0 then Exit;
        end;
      end;
    end
    else
    begin
      result := CompareText(thisChunk, thatChunk);
    end;

    if result <> 0 then Exit;
  end;

  result := s1Length - s2Length;
end;

end.
