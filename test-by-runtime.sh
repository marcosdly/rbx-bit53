echo "> Running tests for each runtime context..."

run_with_args() {
  ARGS="$1"
  echo ">> Run tests with luau options: $ARGS"
  luau $ARGS ./test.luau
  if [ $? -eq 0 ]; then echo ">> PASS"; else echo ">> FAILED"; fi
}

for optimization_level in 0 1 2; do
  for debug_level in 0 1 2; do
    run_with_args "-O$optimization_level -g$debug_level"
    run_with_args "-O$optimization_level -g$debug_level --codegen"
  done
done
