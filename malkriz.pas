program malkriz; (* lightweight griddler solver, usually uses less than 1MB of RAM *)
uses crt; (* used for gotoxy and wherey, this for some reason clears the screen on startup if stdin is not a tty (= a bug) *)

type
  cell = (unknown, empty, full); (* one cell of the griddler *)
  cellrow = array of cell; (* one row/column of the griddler *)
  cellboard = array of cellrow; (* the whole griddler *)

  side = array of integer; (* one row/column of numbers on the side/top *)
  fullside = array of side; (* all rows/columns of numbers on the side/top *)
  rowwhites = array of integer; (* a combination of the number of white cells between black cells *)

var
  sizex,sizey,thissize,othersize,i,j,tmp,x,pass:integer;
    (* sizex, sizey: the size of the griddler
       thissize: the size of the griddler in the direction that is currently being traversed
       othersize: the other than thissize
       i, j: iterators
       tmp: the number of white/black cells found/written when working with combinations
       x: the index of the current cell when working with combinations
       pass: the number of passes *)
  unknowns:integer;
    (* the number of unknown cells *)
  sideleft,sidetop,thisside:fullside;
    (* sideleft, sidetop: the numbers on the left and top
       thisside: one of sideleft or sidetop, depending on the boolean direction *)
  board:cellboard;
    (* the full working board *)
  tmprow:cellrow;
    (* the row/column that is currently being processed *)
  error,changed,direction,quiet,firstvalidfound,doubleout:boolean;
    (* error: an error occured during input, or the current combination is invalid
       changed: true if at least one cell was changed during the last iteration, program ends if false
       direction: true if going row-by-row, false if going column-by-column
       quiet: true if user wants to suppress output
       firstvalidfound: the first valid combination has been found
       doubleout: true if the user wants double output *)
  check:array[false..true] of array of boolean;
    (* the first index is the direction boolean above
       if a cell is changed, the corresponding boolean in the opposite direction is set to true
       if a new row/column is being initialised and this is false, it is skipped because nothing changed from last time *)
  inp:string;
    (* a single line of input the user enters *)
  thiscombination:rowwhites;
    (* the current combination of the lengths of groups of white cells *)
  beginrow:tcrtcoord;
    (* the Y coordinate position is saved here when solving is starting *)

function kaccess(x,y:integer;row:boolean;k:cellboard):cell; (* access a cell, if going rowwise, swap x and y around so that we can use the same code for both rows and columns *)
  begin
    if row then
      kaccess := k[x][y]
    else
      kaccess := k[y][x]
  end;

procedure kset(x,y:integer;row:boolean;var k:cellboard;v:cell); (* same as above, but sets a cells instead of reading it *)
  begin
    if row then
      k[x][y] := v
    else
      k[y][x] := v
  end;

function firstcombination(thisside:side;size:integer):rowwhites; (* calculate the first combination of lengths of groups of white cells *)
  var
    i:integer;
    result:rowwhites;
  begin
    setlength(result,length(thisside) + 1); (* there is 1 more white group than there are black groups *)
    result[length(result) - 1] := 0; (* the last one is 0 *)
    for i := length(result) - 2 downto 1 do (* all except the first and last are 1 *)
      result[i] := 1;
    result[0] := size - length(result) + 2; (* the first is the rest: the total number of blacks - the number of 1s in the other fields *)
    for i := 0 to length(thisside) - 1 do
      result[0] := result[0] - thisside[i]; (* ... and - the black cells *)
    firstcombination := result
  end;

function nextcombination(var thisrowwhites:rowwhites):boolean; (* returns false if done *)
  var
    i,x:integer;
  begin
    (* description of algorithm:
        - save last field into x and make it 0
	- going from the end, if any non-end field is > 1, decrement it and add x and 1 to the next field, return true
	- if all non-end fields == 1 & the first field == 0, return false
	- add x and 1 to second field and decrement first one
    *)
    x := thisrowwhites[length(thisrowwhites) - 1];
    thisrowwhites[length(thisrowwhites) - 1] := 0;
    for i := length(thisrowwhites) - 2 downto 1 do
      if thisrowwhites[i] > 1 then begin
        dec(thisrowwhites[i]);
	inc(thisrowwhites[i+1],x + 1);
	nextcombination := true;
	exit
      end;
    if thisrowwhites[0] = 0 then begin
      thisrowwhites[length(thisrowwhites) - 1] := x;
      nextcombination := false;
      exit
    end;
    dec(thisrowwhites[0]);
    inc(thisrowwhites[1],x + 1);
    nextcombination := true;
    exit
  end;

procedure dispboard(direction:boolean;row:integer); (* display the entire board, writing a * on the currently processing field *)
  var
    i,j:integer;
  begin
    if not quiet then
      gotoxy(1,beginrow);
    writeln('#unknowns = ',unknowns,'   ');
    for i := 0 to sizey - 1 do begin
      for j := 0 to sizex - 1 do begin
        case board[i][j] of
	  unknown:begin
	    write('-');
	    if doubleout then
	      write('-')
	  end;
          empty:begin
	    write(' ');
	    if doubleout then
	      write(' ')
	  end;
	  full:begin
	    write('#');
	    if doubleout then
	      write('#')
	  end
	end
      end;
      if direction and (i = (row+1)) then (* if rows are being processed and this is the row, write *, otherwise, clear a possible previous * *)
	write(' *')
      else
	write('  ');
     writeln
    end;
    if direction and (row = sizey) then (* if the very last row has just finished, write * in the first column *)
      write('* ')
    else if not direction then begin (* if doing columns *)
      for i := 1 to row do begin
        write(' ');
	if doubleout then
	  write(' ')
      end;
      write('* ')
    end else
      for i := 0 to sizex do begin
        write(' ');
	if doubleout then
	  write(' ')
      end
  end;

begin
  clrscr; (* TODO better fix: temporary solution for bug with crt (sets cursor to 1,1 if stdin is not a tty, but doesn't clear screen, making the output ugly and overlaying on the previous prompt) *)
   (* parse parameters *)
  quiet := false;
  doubleout := false;
  for i := 1 to paramcount do
    for j := 1 to length(paramstr(i)) do
    case paramstr(i)[j] of
      'q':quiet := true;
      'h':begin
        writeln('usage: malkriz [opts]');
	writeln('possible options:');
	writeln(' q: quiet mode');
	writeln(' h: show this');
	writeln(' d: double characters output');
	writeln('(a ''-'' before the options is not required');
	writeln('input is always read from stdin')
      end;
      'd':doubleout := true;
    end;
    
   (* get input *)
  if not quiet then
    write('#columns: ');
  readln(sizex);
  if not quiet then
    write('#rows: ');
  readln(sizey);
  if not quiet then
    writeln('allocating memory...');
  setlength(sideleft,sizey);
  setlength(sidetop,sizex);
  setlength(check[false],sizex);
  if sizex > sizey then
    setlength(tmprow,sizex)
  else
    setlength(tmprow,sizey);
  for i := 0 to sizex - 1 do
    check[false][i] := true;
  setlength(check[true],sizey);
  for i := 0 to sizey - 1 do
    check[true][i] := true;
  setlength(board,sizey);
  for i := 0 to sizey - 1 do begin
    setlength(board[i],sizex);
    for j := 0 to sizex - 1 do
      board[i][j] := unknown
  end;
  unknowns := sizex * sizey;

  i := 0;
  while i < sizex do begin
    setlength(sidetop[i],0);
    if not quiet then
      write('column #',i+1,': ');
    readln(inp);

    error := false;
    tmp := 0;
    for j := 1 to length(inp) do
      if (inp[j] >= '0') and (inp[j] <= '9') then
        tmp := tmp * 10 + ord(inp[j]) - ord('0')
      else if inp[j] = ' ' then begin
        setlength(sidetop[i],length(sidetop[i]) + 1);
	sidetop[i][length(sidetop[i]) - 1] := tmp;
	tmp := 0
      end else
	error := true;
    if tmp <> 0 then begin
      setlength(sidetop[i],length(sidetop[i]) + 1);
      sidetop[i][length(sidetop[i]) - 1] := tmp
    end;
    tmp := 0;
    for j := 0 to length(sidetop[i]) - 1 do
      inc(tmp,sidetop[i][j]);
    if (tmp + length(sidetop[i]) - 1) > sizey then
      error := true;
    if error then begin
      writeln(stderr,'ERROR',#13);
      setlength(sidetop,length(sidetop) - 1)
    end else inc(i)
  end;

  i := 0;
  while i < sizey do begin
    setlength(sideleft[i],0);
    if not quiet then
      write('row #',i+1,': ');
    readln(inp);

    error := false;
    tmp := 0;
    for j := 1 to length(inp) do
      if (inp[j] >= '0') and (inp[j] <= '9') then
        tmp := tmp * 10 + ord(inp[j]) - ord('0')
      else if inp[j] = ' ' then begin
        setlength(sideleft[i],length(sideleft[i]) + 1);
	sideleft[i][length(sideleft[i]) - 1] := tmp;
	tmp := 0
      end else
	error := true;
    if tmp <> 0 then begin
      setlength(sideleft[i],length(sideleft[i]) + 1);
      sideleft[i][length(sideleft[i]) - 1] := tmp
    end;
    tmp := 0;
    for j := 0 to length(sideleft[i]) - 1 do
      inc(tmp,sideleft[i][j]);
    if (tmp + length(sideleft[i]) - 1) > sizex then
      error := true;
    if error then begin
      writeln(stderr,'ERROR',#13);
      setlength(sideleft,length(sideleft) - 1)
    end else inc(i)
  end;

   (* start solving *)
  direction := false;
  changed := true;
  beginrow := wherey; (* TODO check screen size *)
  pass := 0;
  repeat begin (* repeat until no change happened *)
    direction := not direction; (* start with processing row-wise and switch next time *)
    if direction then begin
      thisside := sideleft;
      thissize := sizex;
      othersize := sizey;
      inc(pass)
    end else begin
      thisside := sidetop;
      thissize := sizey;
      othersize := sizex;
      changed := false
    end;
    for i := 0 to othersize - 1 do begin (* iterate row-wise/column-wise *)
      if not check[direction][i] then (* if this row/column was not changed, skip it *)
        continue;
      check[direction][i] := false; (* mark as unchanged *)
       (* first search for the first valid combination
          copy that into tmprow
          for every next valid combination, if a cell doesn't match tmprow, make that cell in tmprow unknown
          copy tmprow into board, and if something changed, set check[] and changed *)
      firstvalidfound := false;
      thiscombination := firstcombination(thisside[i],thissize);
      repeat begin
        error := false;
	x := 0;
        for j := 0 to length(thisside[i]) - 1 do begin
	  for tmp := 1 to thiscombination[j] do
	    if kaccess(i,x,direction,board) = full then begin
	      error := true;
	      break
            end else
	      inc(x);
	  if error then
	    break;
	  for tmp := 1 to thisside[i][j] do
	    if kaccess(i,x,direction,board) = empty then begin
	      error := true;
	      break
	    end else
	      inc(x);
	  if error then
	    break;
	end;
	for tmp := 1 to thiscombination[length(thiscombination) - 1] do
	  if kaccess(i,x,direction,board) = full then begin
	    error := true;
	    break
	  end else
	    inc(x);
        if not error then
	  if firstvalidfound then begin
	    x := 0;
	    for j := 0 to length(thisside[i]) - 1 do begin
	      for tmp := 1 to thiscombination[j] do begin
		if tmprow[x] = full then
		  tmprow[x] := unknown;
		inc(x)
	      end;
	      for tmp := 1 to thisside[i][j] do begin
		if tmprow[x] = empty then
		  tmprow[x] := unknown;
		inc(x)
	      end;
	    end;
	    for tmp := 1 to thiscombination[length(thiscombination) - 1] do begin
	      if tmprow[x] = full then
		tmprow[x] := unknown;
	      inc(x)
	    end
	  end else begin
	    firstvalidfound := true;
	    x := 0;
	    for j := 0 to length(thisside[i]) - 1 do begin
	      for tmp := 1 to thiscombination[j] do begin
	        tmprow[x] := empty;
		inc(x)
	      end;
	      for tmp := 1 to thisside[i][j] do begin
	        tmprow[x] := full;
		inc(x)
	      end
	    end;
	    for tmp := 1 to thiscombination[length(thiscombination) - 1] do begin
	      tmprow[x] := empty;
	      inc(x)
	    end
	  end
      end until not nextcombination(thiscombination);
      for j := 0 to thissize - 1 do
        if (kaccess(i,j,direction,board) = unknown) and (tmprow[j] <> unknown) then begin
	  dec(unknowns);
	  check[not direction][j] := true;
	  changed := true;
	  kset(i,j,direction,board,tmprow[j])
	end;
      if not quiet then
        dispboard(direction,i)
    end;
  end until (unknowns = 0) or ((not changed) and direction);
  dispboard(true,sizey+2); (* +2 to make sure no * is displayed *)
  gotoxy(1,wherey);
  writeln(pass,' passes');
end.
