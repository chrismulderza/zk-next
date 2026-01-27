#!/usr/bin/env bats

# ============================================================================
# Help System Tests
# ============================================================================

@test "zkn --help shows help and exits 0" {
  run ./bin/zkn --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
  [[ "$output" == *"add"* ]]
  [[ "$output" == *"init"* ]]
  [[ "$output" == *"completion"* ]]
}

@test "zkn -h shows help and exits 0" {
  run ./bin/zkn -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "zkn without args shows help and exits 0" {
  run ./bin/zkn
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "zkn add --help shows help and exits 0" {
  run ./bin/zkn add --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"add"* ]]
}

@test "zkn add -h shows help and exits 0" {
  run ./bin/zkn add -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"add"* ]]
}

@test "zkn init --help shows help and exits 0" {
  run ./bin/zkn init --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"init"* ]]
}

@test "zkn init -h shows help and exits 0" {
  run ./bin/zkn init -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"zk-next"* ]]
  [[ "$output" == *"init"* ]]
}

# ============================================================================
# Completion Command Tests
# ============================================================================

@test "zkn completion generates bash completion script" {
  run ./bin/zkn completion
  [ "$status" -eq 0 ]
  [[ "$output" == *"# zk-next bash completion"* ]]
  [[ "$output" == *"_zkn()"* ]]
  [[ "$output" == *"complete -F _zkn zkn"* ]]
}

@test "zkn _completion is alias for completion" {
  run ./bin/zkn _completion
  [ "$status" -eq 0 ]
  [[ "$output" == *"# zk-next bash completion"* ]]
  [[ "$output" == *"_zkn()"* ]]
  [[ "$output" == *"complete -F _zkn zkn"* ]]
}

# ============================================================================
# Command Execution Tests
# ============================================================================

@test "zkn init" {
  mkdir -p test_init_dir
  cd test_init_dir
  run ../bin/zkn init
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialized"* ]]
  [ -d .zk ]
  [ -f .zk/config.yaml ]
  cd ..
  rm -rf test_init_dir
}

@test "zkn add" {
  rm -rf test_add_dir
  mkdir -p test_add_dir
  cd test_add_dir
  ../bin/zkn init
  rm .zk/config.yaml
  export HOME="$PWD/home"
  mkdir -p "$HOME/.config/zk-next/templates"
  cat > "$HOME/.config/zk-next/templates/default.erb" << 'EOF'
---
id: <%= id %>
type: default
---
# <%= type %>
Content
EOF
   cat > "$HOME/.config/zk-next/config.yaml" << 'EOF'
---
notebook_path: "."
templates:
- type: default
  template_file: default.erb
  filename_pattern: '{type}-{date}.md'
  subdirectory: ''
EOF
  run ../bin/zkn add default
  [ "$status" -eq 0 ]
  [[ "$output" == *"Note created"* ]]
  [ -f *.md ]
  cd ..
  rm -rf test_add_dir
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "zkn unknown command shows error and exits 1" {
  run ./bin/zkn unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: zkn <command> [options]"* ]]
  [[ "$output" == *"Commands: add, init, completion"* ]]
  [[ "$output" == *"Run 'zkn --help' for more information."* ]]
}
