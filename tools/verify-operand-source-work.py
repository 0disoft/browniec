"""Verify ordinary grouped, CALL, unary and postfix/cast continuations."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('semantic_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/operand-source-work'
bottom.MODULES = {'expression_lowering': None, 'semantic_lowering': None, 'body_lowering': None, 'body_source_work': None, 'call_operand_kernel': None, 'tail_lowering': None}
bottom.EXTRA_INPUTS = {'tools/verify-operand-source-work.py'}
# Narrow recheck for completion guards and mixed depth after a composed snapshot.
if '--kernel-only' in sys.argv:
    sys.argv.remove('--kernel-only')
    bottom.DIRECTORY = 'build/operand-completion-work'
    bottom.MODULES = {'call_operand_kernel': None, 'body_lowering': ['nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics', 'captured_scalar_results_keep_prefix_order_and_lexical_cleanup']}
if '--unary-only' in sys.argv:
    sys.argv.remove('--unary-only')
    bottom.DIRECTORY = 'build/operand-unary-work'
    bottom.MODULES = {'expression_lowering': ['unary_children_defer_tokens_checks_and_emission_on_shared_frames'],
                      'body_lowering': ['unary_operands_keep_raw_precedence_context_minima_and_errors',
                                        'unary_depth_and_mixed_capture_exits_preserve_raw_limits_on_default_stack']}
if '--tail-only' in sys.argv:
    sys.argv.remove('--tail-only')
    bottom.DIRECTORY = 'build/operand-tail-work'
    bottom.MODULES = {'tail_lowering': None, 'semantic_lowering': None,
                      'body_lowering': ['postfix_and_cast_operands_preserve_raw_ir_precedence_and_diagnostics',
                                        'postfix_capture_failures_ranges_and_register_limits_preserve_raw_prefixes',
                                        'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics',
                                        'unary_depth_and_mixed_capture_exits_preserve_raw_limits_on_default_stack']}
if '--preflight-only' in sys.argv:
    sys.argv.remove('--preflight-only')
    bottom.DIRECTORY = 'build/operand-preflight-work'
    bottom.MODULES = {'preflight_lowering': None, 'expression_lowering': ['expression_depth_rejects_before_requesting_an_operand'],
                      'body_lowering': ['postfix_and_cast_operands_preserve_raw_ir_precedence_and_diagnostics',
                                        'grouped_operands_match_raw_ir_and_preserve_postfix_cast_context',
                                        'scalar_call_operands_preserve_raw_arguments_suffixes_and_errors',
                                        'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics',
                                        'unary_depth_and_mixed_capture_exits_preserve_raw_limits_on_default_stack',
                                        'preflight_legacy_boundaries_and_record_binary_groups_keep_raw_ir_and_errors']}
if '--preflight-boundary-only' in sys.argv:
    sys.argv.remove('--preflight-boundary-only')
    bottom.DIRECTORY = 'build/operand-preflight-boundary'
    bottom.MODULES = {'body_lowering': ['preflight_legacy_boundaries_and_record_binary_groups_keep_raw_ir_and_errors']}
if __name__ == '__main__':
    bottom.main()
