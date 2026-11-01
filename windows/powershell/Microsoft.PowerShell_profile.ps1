oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\obk.toml" | Invoke-Expression

$env:EDITOR = 'zed --wait'
$env:VISUAL = $env:EDITOR


function scf {
    scoop update
    scoop update *
    scoop cleanup *
    scoop cache rm *
}

# Same shortcuts as fish and zsh. PowerShell aliases can't carry arguments, so
# these are functions. gp, gl and gcm are built-in read-only aliases
# (Get-ItemProperty, Get-Location, Get-Command), removed first so the git
# versions win; the cmdlets still work by their full names.
foreach ($name in 'gp', 'gl', 'gcm') { Remove-Item "Alias:$name" -Force -ErrorAction SilentlyContinue }
function gp { git push @args }
function gl { git pull @args }
function gcm { git commit -m @args }

# common typos (cd.. is built in)
function gti { git @args }
function exti { exit }
function celar { Clear-Host }
function claer { Clear-Host }
function clera { Clear-Host }

# eza: ls with icons and git status, when installed
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ll { eza -l --icons --git @args }
    function lal { eza -la --icons --git @args }
} else {
    function ll { Get-ChildItem @args }
    function lal { Get-ChildItem -Force @args }
}
# dust: du as a readable tree, when installed
if (Get-Command dust -ErrorAction SilentlyContinue) { Set-Alias du dust }
