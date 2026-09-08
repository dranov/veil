import Veil.Core.UI.Verifier.TraceCounterexample

open Veil

#guard isSpecificActionParam (traceParamName "_tr1" 0 `my_arg) == some (1, 0, `my_arg)
#guard isSpecificActionParam (traceParamName "_tr1" 0 `my_arg_act_more) == some (1, 0, `my_arg_act_more)
#guard isAnyActionParam (traceParamName (traceActionParamPrefix 1 `send_args) 0 `value) == some (1, `send_args, 0, `value)
#guard isAnyActionParam (traceParamName (traceActionParamPrefix 2 `x_act__arg) 3 `my_arg) == some (2, `x_act__arg, 3, `my_arg)
#guard isAnyActionParam `_tr1_act999_send_arg0_value == none
#guard isSpecificActionParam `_tr_arg0_value == none
#guard isAnyActionParam (traceParamName (traceActionParamPrefix 2 `«send.消息_arg») 3 `«my arg»)
  == some (2, `«send.消息_arg», 3, `«my arg»)
#guard decodeTraceName (encodeTraceName `Namespace.action) == some `Namespace.action
#guard decodeTraceName (encodeTraceName (.num `action 42)) == some (.num `action 42)
#guard decodeTraceName "[true]" == none
