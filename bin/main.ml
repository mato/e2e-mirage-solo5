open Lib
open Shexp_process

let main =
    Logged.eval setup_switch;
    Logged.eval install_mirage;
    Logged.eval build_unikernel;
    Logged.eval setup_net;
    Logged.eval setup_block;
    Logged.eval init_unikernel;
    let expected = [ 1; 2; 3 ] in
    Logged.eval (List.iter ~f:run_smoketest expected)

let () = main
