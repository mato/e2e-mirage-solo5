open Shexp_process
open Shexp_process.Infix

let run_path = "./run"
let switch_path = "./run/switch"
let src_path = "./unikernel"
let block_path = "./run/disk.img"
let universe_path = "./universe"

let setup_switch = 
    file_exists switch_path >>= function
    | true  -> call [ "rm"; "-rf"; switch_path ]
               >> chdir run_path (call [ "tar"; "-xzf"; "switch.tar.gz" ])
    | false -> call [ "mkdir"; "-p"; switch_path ]
               >> call [ "opam"; "switch"; "create"; switch_path; "4.07.1" ]
               >> chdir run_path
                 (call [ "tar"; "-czf"; "switch.tar.gz"; "switch/" ])

let universe = eval (readdir universe_path)

let abspath path = call [ "readlink"; "-f"; path ] |- read_all >>| String.trim

let with_switch = [ "opam"; "exec"; "--switch=" ^ (eval (abspath switch_path));
                    "--set-switch"; "--" ]

let opam_install args =
  set_env "OPAMYES" "true" (call (with_switch @ [ "opam"; "install" ] @ args))

let opam_pin_add pkg : unit t =
  set_env "OPAMYES" "true" (call (with_switch @
                                  [ "opam"; "pin"; "add"; "-n"; "--dev-repo"; pkg ]))

let install_mirage =
  Shexp_process.List.iter ~f:opam_pin_add universe
  >> opam_install universe

let build_unikernel =
  chdir src_path (
    call (with_switch @ [ "mirage"; "configure"; "-t"; "hvt" ])
    >> call (with_switch @ [ "make"; "depend" ])
    >> call (with_switch @ [ "make" ])
  )

let setup_net =
  let ip args = call ([ "sudo"; "ip" ] @ args) in
  file_exists "/sys/class/net/tap100" >>= function
  | true  -> return ()
  | false -> ip [ "tuntap"; "add"; "tap100"; "mode"; "tap" ]
             >> ip [ "addr"; "add"; "10.0.0.1/24"; "dev"; "tap100" ]
             >> ip [ "link"; "set"; "dev"; "tap100"; "up" ]

let setup_block =
  file_exists block_path >>= function
  | true  -> return ()
  | false -> call [ "dd"; "if=/dev/zero"; "of=" ^ block_path; "bs=512"; "count=1" ]

let init_unikernel =
  call [ src_path ^ "/solo5-hvt"; "--net=tap100"; "--disk=" ^ block_path; src_path ^ "/test.hvt"; "--init" ]

