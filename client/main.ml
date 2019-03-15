open Lwt.Infix

let unikernel_addr =
  let open Unix in ADDR_INET (inet_addr_of_string "10.0.0.2", 23)

let netcat = Lwt_io.with_connection unikernel_addr
    (fun (in_ch, _out_ch) ->
       Lwt_io.read_line in_ch >>= fun line ->
       Lwt_io.write_line Lwt_io.stdout line)

let () = Lwt_main.run netcat
