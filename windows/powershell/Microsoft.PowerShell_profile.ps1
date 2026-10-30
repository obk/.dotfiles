oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\obk.toml" | Invoke-Expression

$env:EDITOR = 'zed --wait'
$env:VISUAL = $env:EDITOR


function scf {
    scoop update
    scoop update *
    scoop cleanup *
    scoop cache rm *
}