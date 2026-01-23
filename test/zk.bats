#!/usr/bin/env bats

@test "zkn without args shows usage" {
  run ./bin/zkn
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "zkn unknown command" {
  run ./bin/zkn unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

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
  run ruby ../lib/cmd/add.rb default
  [ "$status" -eq 0 ]
  [[ "$output" == *"Note created"* ]]
  [ -f *.md ]
  cd ..
  rm -rf test_add_dir
}