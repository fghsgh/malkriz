# malkriz
Malkriz is a lightweight griddler solver (usually, it uses less than 1 MB RAM, a lot better than my previous one, which used 22 GB).
The name of this comes from the Slovak "malovaná krížovka", which means griddler.

## Requirements to compile:
- fpc (tested with 3.0.0+dfsg-2 \[2016/01/28\])
- the fpc runtime library (comes pre-installed with fpc), more specifically the `crt` and `system` units.
After compiling (using `fpc malkriz.pas`), you can run the created executable.

## Command usage:
You do not need to use a `-` to specify options. These are the options available:
- q: doesn't print the griddler while it's being solved.
- h: shows a little help message.
- d: every cell of the griddler is printed as two characters.

## Input:
Input is always read from stdin and written to stdout. There are some example files in the `test` directory of this repository.

## Example usage:
`malkriz < kriz09`: solve the griddler saved in kriz09

## Known bugs:
- No checks are done on whether stdin is a tty and output is always shown to the user.
- It doesn't check if the screen is large enough to display the griddler.
- If stdin is not a tty, the `crt` unit clears the screen for some reason.
