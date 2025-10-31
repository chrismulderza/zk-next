#!/usr/bin/env bats

@test "zk without args shows usage" {
  run ./bin/zk
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "zk unknown command" {
  run ./bin/zk unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "zk init" {
  mkdir -p test_init_dir
  cd test_init_dir
  run ../bin/zk init
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialized"* ]]
  [ -d .zk ]
  [ -f .zk/config.yaml ]
  cd ..
  rm -rf test_init_dir
}

@test "zk add" {
  rm -rf test_add_dir
  mkdir -p test_add_dir
  cd test_add_dir
  ../bin/zk init
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
- default
EOF
  run ruby ../lib/cmd/add.rb default
  [ "$status" -eq 0 ]
  [[ "$output" == *"Note created"* ]]
  [ -f *.md ]
  cd ..
  rm -rf test_add_dir
}