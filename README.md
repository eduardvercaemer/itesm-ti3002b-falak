# falak

falak compiler written in zig

# instructions

You will need zig installed on your system https://ziglang.org/download/

```sh
# To run the lexer on a file
zig run src/main.zig -- examples/001_hello_world.falak
```

The program will print all of the tokens with their line of appearance, the kind of token,
and the relevant information.


#### references

1. [falak specification](https://arielortiz.info/s202113/tc3048/falak/falak_language_spec.html#_introduction)

