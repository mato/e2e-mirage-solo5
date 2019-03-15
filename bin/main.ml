open Lib
open Shexp_process

let main =
    Logged.eval setup_switch;
    Logged.eval install_mirage;
    Logged.eval build_unikernel;
    Logged.eval setup_net;
    Logged.eval setup_block;
    Logged.eval init_unikernel;
    Logged.eval run_smoketest

let () = main
