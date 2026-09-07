import Veil.Core.UI.Verifier.TraceCounterexample

open Veil

#guard isSpecificActionParam `_tr1_arg0_my_arg == some (1, 0, `my_arg)
#guard isSpecificActionParam `_tr1_arg0_my_arg_act_more == some (1, 0, `my_arg_act_more)
#guard isAnyActionParam `_tr1_act9_send_args_arg0_value == some (1, `send_args, 0, `value)
#guard isAnyActionParam `_tr2_act10_x_act__arg_arg3_my_arg == some (2, `x_act__arg, 3, `my_arg)
#guard isAnyActionParam `_tr1_act999_send_arg0_value == none
#guard isSpecificActionParam `_tr_arg0_value == none
