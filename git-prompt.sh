# bash/zsh git prompt support
#
# Copyright (C) 2013 David Xu
# Based on the earlier work by Shawn O. Pearce <spearce@spearce.org>
# Distributed under the GNU General Public License, version 2.0.
#
# This script allows you to see the current branch in your prompt,
# posh-git style
#
# To enable:
#
#    1) Copy this file to somewhere (e.g. ~/.git-prompt.sh).
#    2) Add the following line to your .bashrc/.zshrc:
#        source ~/.git-prompt.sh
#    3a) Change your PS1 to call __git_ps1 as
#        command-substitution:
#        Bash: PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '
#        ZSH:  PS1='[%n@%m %c$(__git_ps1 " (%s)")]\$ '
#        the optional argument will be used as format string.
#    3b) Alternatively, if you are using bash, __git_ps1 can be
#        used for PROMPT_COMMAND with two parameters, <pre> and
#        <post>, which are strings you would put in $PS1 before
#        and after the status string generated by the git-prompt
#        machinery.  e.g.
#           PROMPT_COMMAND='__git_ps1 "\u@\h:\w" "\\\$ "'
#        will show username, at-sign, host, colon, cwd, then
#        various status string, followed by dollar and SP, as
#        your prompt.
#        Optionally, you can supply a third argument with a printf
#        format string to finetune the output of the branch status
#
# The argument to __git_ps1 will be displayed only if you are currently
# in a git repository.  The %s token will be the name of the current
# branch.
#
# __gitdir accepts 0 or 1 arguments (i.e., location)
# returns location of .git repo
# __git_ps1 accepts 0 or 1 arguments (i.e., format string)
# when called from PS1 using command substitution
# in this mode it prints text to add to bash PS1 prompt (includes branch name)
#
# __git_ps1 requires 2 or 3 arguments when called from PROMPT_COMMAND (pc)
# in that case it _sets_ PS1. The arguments are parts of a PS1 string.
# when two arguments are given, the first is prepended and the second appended
# to the state string when assigned to PS1.
# The optional third parameter will be used as printf format string to further
# customize the output of the git-status string.
#
# CONFIG OPTIONS
# ==============
#
# This should work out of the box, but there are some options available, mostly
# setting things in the local git config for
# per-repository options.
# ```
# bash.describeStyle
# bash.enableFileStatus
# bash.enableGitStatus
# bash.showStatusWhenZero
# bash.showUpstream
# ```
#
# bash.describeStyle
# ------------------
#
# This option controls if you would like to see more information about the
# identity of commits checked out as a detached `HEAD`. This is also controlled
# by the legacy environment variable `GIT_PS1_DESCRIBESTYLE`.
#
# Option   | Description
# -------- | -----------
# contains | relative to newer annotated tag `(v1.6.3.2~35)`
# branch   | relative to newer tag or branch `(master~4)`
# describe | relative to older annotated tag `(v1.6.3.1-13-gdd42c2f)`
# default  | exactly matching tag
#
# bash.enableFileStatus
# ---------------------
#
# Option | Description
# ------ | -----------
# true   | _Default_. The script will query for all file indicators every time.
# false  | No file indicators will be displayed. The script will not query
#          upstream for differences. Branch color-coding information is still
#          displayed.
#
# bash.enableGitStatus
# --------------------
#
# Option | Description
# ------ | -----------
# true   | _Default_. Color coding and indicators will be shown.
# false  | The script will not run.
#
# bash.showStashState
# -------------------
#
# Option | Description
# ------ | -----------
# true   | _Default_. An indicator will display if the stash is not empty.
# false  | An indicator will not display the stash status.
#
# bash.showStatusWhenZero
# -----------------------
#
# Option | Description
# ------ | -----------
# true   | Indicators will be shown even if there are no updates to the index or
#          working tree.
# false  | _Default_. No file change indicators will be shown if there are no
#          changes to the index or working tree.
#
# bash.showUpstream
# -----------------
#
# By default, `__git_ps1` will compare `HEAD` to your `SVN` upstream if it can
# find one, or `@{upstream}` otherwise. This is also controlled by the legacy
# environment variable `GIT_PS1_SHOWUPSTREAM`.
#
# Option | Description
# ------ | -----------
# legacy | Does not use the `--count` option available in recent versions of
#          `git-rev-list`
# git    | _Default_. Always compares `HEAD` to `@{upstream}`
# svn    | Always compares `HEAD` to `SVN` upstream
__git_ps1 ()
{
    if [ "$(git config --bool bash.enableGitStatus)" == "false" ]; then return; fi

    local DefaultForegroundColor='\e[m' # Default no color
    local DefaultBackgroundColor=

    local BeforeText=' ['
    local BeforeForegroundColor='\e[1;33m' # Yellow
    local BeforeBackgroundColor=
    local DelimText=' |'
    local DelimForegroundColor='\e[1;33m' # Yellow
    local DelimBackgroundColor=

    local AfterText=']'
    local AfterForegroundColor='\e[1;33m' # Yellow
    local AfterBackgroundColor=

    local BranchForegroundColor='\e[1;36m' # Cyan
    local BranchBackgroundColor=
    local BranchAheadForegroundColor='\e[1;32m' # Green
    local BranchAheadBackgroundColor=
    local BranchBehindForegroundColor='\e[0;31m' # Red
    local BranchBehindBackgroundColor=
    local BranchBehindAndAheadForegroundColor='\e[1;33m' # Yellow
    local BranchBehindAndAheadBackgroundColor=

    local BeforeIndexText=""
    local BeforeIndexForegroundColor='\e[1;32m' #Dark green
    local BeforeIndexBackgroundColor=

    local IndexForegroundColor='\e[1;32m' # Dark green
    local IndexBackgroundColor=

    local WorkingForegroundColor='\e[0;31m' # Dark red
    local WorkingBackgroundColor=

    local StashForegroundColor='\e[0;34m' # Darker blue
    local StashBackgroundColor=


    local EnableFileStatus=`git config --bool bash.enableFileStatus`
    case "$EnableFileStatus" in
        true)  EnableFileStatus=true ;;
        false) EnableFileStatus=false ;;
        *)     EnableFileStatus=true ;;
    esac
    local ShowStatusWhenZero=`git config --bool bash.showStatusWhenZero`
    case "$ShowStatusWhenZero" in
        true)  ShowStatusWhenZero=true ;;
        false) ShowStatusWhenZero=false ;;
        *)     ShowStatusWhenZero=false ;;
    esac
    local ShowStashState=`git config --bool bash.showStashState`
    case "$ShowStashState" in
        true)  ShowStashState=true ;;
        false) ShowStashState=false ;;
        *)     ShowStashState=true ;;
    esac

    aheadBy=0                   # these globals are updated by __git_ps1_showupstream
    behindBy=0

    local is_pcmode=false
    local is_detached=false
    local ps1pc_start='\u@\h:\w '
    local ps1pc_end='\$ '
    local printf_format='%s'

    case "$#" in
        2|3)
            is_pcmode=true
            ps1pc_start="$1"
            ps1pc_end="$2"
            printf_format="${3:-$printf_format}"
            ;;
        0|1)
            printf_format="${1:-$printf_format}"
            ;;
        *)
            return
            ;;
    esac

    local g="$(__gitdir)"
    if [ -z "$g" ]; then
        if [ $is_pcmode ]; then
            #In PROMPT_COMMAND mode PS1 always needs to be set
            PS1="$ps1pc_start$ps1pc_end"
        fi
        return
    fi
    local rebase=""
    local b=""
    local step=""
    local total=""
    if [ -d "$g/rebase-merge" ]; then
        b=$(cat "$g/rebase-merge/head-name" 2>/dev/null)
        step=$(cat "$g/rebase-merge/msgnum" 2>/dev/null)
        total=$(cat "$g/rebase-merge/end" 2>/dev/null)
        if [ -f "$g/rebase-merge/interactive" ]; then
            rebase="|REBASE-i"
        else
            rebase="|REBASE-m"
        fi
    else
        if [ -d "$g/rebase-apply" ]; then
            step=$(cat "$g/rebase-apply/next")
            total=$(cat "$g/rebase-apply/last")
            if [ -f "$g/rebase-apply/rebasing" ]; then
                rebase="|REBASE"
            elif [ -f "$g/rebase-apply/applying" ]; then
                rebase="|AM"
            else
                rebase="|AM/REBASE"
            fi
        elif [ -f "$g/MERGE_HEAD" ]; then
            rebase="|MERGING"
        elif [ -f "$g/CHERRY_PICK_HEAD" ]; then
            rebase="|CHERRY-PICKING"
        elif [ -f "$g/REVERT_HEAD" ]; then
            rebase="|REVERTING"
        elif [ -f "$g/BISECT_LOG" ]; then
            rebase="|BISECTING"
        fi

        b="$(git symbolic-ref HEAD 2>/dev/null)" || {
            is_detached=true
            local output="$(git config -z --get bash.describeStyle)"
            if [ -n "$output" ]; then
                GIT_PS1_DESCRIBESTYLE=$output
            fi
            b="$(
            case "${GIT_PS1_DESCRIBESTYLE-}" in
            (contains)
                git describe --contains HEAD ;;
            (branch)
                git describe --contains --all HEAD ;;
            (describe)
                git describe HEAD ;;
            (* | default)
                git describe --tags --exact-match HEAD ;;
            esac 2>/dev/null)" ||

            b="$(cut -c1-7 "$g/HEAD" 2>/dev/null)..." ||
            b="unknown"
            b="($b)"
        }
    fi

    if [ -n "$step" ] && [ -n "$total" ]; then
        rebase="$rebase $step/$total"
    fi

    local isDirtyUnstaged=""
    local isDirtyStaged=""
    local StashText=""
    local isBare=""

    if [ "true" = "$(git rev-parse --is-inside-git-dir 2>/dev/null)" ]; then
        if [ "true" = "$(git rev-parse --is-bare-repository 2>/dev/null)" ]; then
            isBare="BARE:"
        else
            b="GIT_DIR!"
        fi
    elif [ "true" = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
        if $ShowStashState; then
            git rev-parse --verify refs/stash >/dev/null 2>&1 && StashText="$"
        fi
        __git_ps1_show_upstream
    fi

    # show index status and working directory status
    if $EnableFileStatus; then
        local indexAdded=0
        local indexModified=0
        local indexDeleted=0
        local indexUnmerged=0
        local filesAdded=0
        local filesModified=0
        local filesDeleted=0
        local filesUnmerged=0
        while IFS="\n" read -r tag rest
        do
            case "${tag:0:1}" in
                A )
                    (( indexAdded++ ))
                    ;;
                M )
                    (( indexModified++ ))
                    ;;
                R )
                    (( indexModified++ ))
                    ;;
                C )
                    (( indexModified++ ))
                    ;;
                D )
                    (( indexDeleted++ ))
                    ;;
                U )
                    (( indexUnmerged++ ))
                    ;;
            esac
            case "${tag:1:1}" in
                \? )
                    (( filesAdded++ ))
                    ;;
                A )
                    (( filesAdded++ ))
                    ;;
                M )
                    (( filesModified++ ))
                    ;;
                D )
                    (( filesDeleted++ ))
                    ;;
                U )
                    (( filesUnmerged++ ))
                    ;;
            esac
        done <<< "`git status --porcelain`"
    fi

    local gitstring=
    local branchstring="$isBare${b##refs/heads/}"
    # before-branch text
    gitstring="\[$BeforeBackgroundColor\]\[$BeforeForegroundColor\]$BeforeText"

    # branch
    if [ $behindBy -gt 0 ] && [ $aheadBy -gt 0 ]; then
        gitstring+="\[$BranchBehindAndAheadBackgroundColor\]\[$BranchBehindAndAheadForegroundColor\]$branchstring"
    elif [ $behindBy -gt 0 ]; then
        gitstring+="\[$BranchBehindBackgroundColor\]\[$BranchBehindForegroundColor\]$branchstring"
    elif [ $aheadBy -gt 0 ]; then
        gitstring+="\[$BranchAheadBackgroundColor\]\[$BranchAheadForegroundColor\]$branchstring"
    else
        gitstring+="\[$BranchBackgroundColor\]\[$BranchForegroundColor\]$branchstring"
    fi

    local indexCount="$(( $indexAdded + $indexModified + $indexDeleted + $indexUnmerged ))"
    local workingCount="$(( $filesAdded + $filesModified + $filesDeleted + $filesUnmerged ))"
    # index status
    if $EnableFileStatus; then
        if [ $indexCount -ne 0 ] || $ShowStatusWhenZero; then
            gitstring+="\[$IndexBackgroundColor\]\[$IndexForegroundColor\] +$indexAdded ~$indexModified -$indexDeleted"
        fi
        if [ $indexUnmerged -ne 0 ]; then
            gitstring+=" \[$IndexBackgroundColor\]\[$IndexForegroundColor\]!$indexUnmerged"
        fi
        if [ $indexCount -ne 0 ] && ([ $workingCount -ne 0 ] || $ShowStatusWhenZero); then
            gitstring+="\[$DelimBackgroundColor\]\[$DelimForegroundColor\]$DelimText"
        fi
    fi
    if [ $EnableFileStatus ]; then
        if [ $workingCount -ne 0 ] || $ShowStatusWhenZero; then
            gitstring+="\[$WorkingBackgroundColor\]\[$WorkingForegroundColor\] +$filesAdded ~$filesModified -$filesDeleted"
        fi
        if [ $filesUnmerged -ne 0 ]; then
            gitstring+=" \[$WorkingBackgroundColor\]\[$WorkingForegroundColor\]!$filesUnmerged"
        fi
    fi
    gitstring+=${rebase:+'\[\e[0m\]'$rebase}

    # after-branch text
    gitstring+="\[$AfterBackgroundColor\]\[$AfterForegroundColor\]$AfterText"

    if $ShowStashState; then
        gitstring+="\[$StashBackgroundColor\]\[$StashForegroundColor\]"$StashText
    fi
    gitstring=`printf -- "$printf_format" "$gitstring\[$DefaultBackgroundColor\]\[$DefaultForegroundColor\]"`
    if $is_pcmode; then
        PS1="$ps1pc_start$gitstring$ps1pc_end"
    else
        printf -- "$printf_format" "$gitstring"
    fi
}

__gitdir ()
{
    # Note: this function is duplicated in git-completion.bash
    # When updating it, make sure you update the other one to match.
    if [ -z "${1-}" ]; then
        if [ -n "${__git_dir-}" ]; then
            echo "$__git_dir"
        elif [ -n "${GIT_DIR-}" ]; then
            test -d "${GIT_DIR-}" || return 1
            echo "$GIT_DIR"
        elif [ -d .git ]; then
            echo .git
        else
            git rev-parse --git-dir 2>/dev/null
        fi
    elif [ -d "$1/.git" ]; then
        echo "$1/.git"
    else
        echo "$1"
    fi
}

# Updates the global variables `aheadBy` and `behindBy`
__git_ps1_show_upstream ()
{
    local key value
    local svn_remote svn_url_pattern n
    local upstream=git          # default
    legacy=""

    svn_remote=()
    # get some config options from git-config
    local output="$(git config -z --get-regexp '^(svn-remote\..*\.url|bash\.showUpstream)$' 2>/dev/null | tr '\0\n' '\n ')"
    while read -r key value; do
        case "$key" in
        bash.showUpstream)
            GIT_PS1_SHOWUPSTREAM="$value"
            if [[ -z "${GIT_PS1_SHOWUPSTREAM}" ]]; then
                return
            fi
            ;;
        svn-remote.*.url)
            svn_remote[ $((${#svn_remote[@]} + 1)) ]="$value"
            svn_url_pattern+="\\|$value"
            upstream=svn+git # default upstream is SVN if available, else git
            ;;
        esac
    done <<< "$output"

    # parse configuration values
    for option in ${GIT_PS1_SHOWUPSTREAM}; do
        case "$option" in
        git|svn) upstream="$option" ;;
        legacy)  legacy=1  ;;
        esac
    done

    # Find our upstream
    case "$upstream" in
    git)    upstream="@{upstream}" ;;
    svn*)
        # get the upstream from the "git-svn-id: ..." in a commit message
        # (git-svn uses essentially the same procedure internally)
        local svn_upstream=($(git log --first-parent -1 \
                    --grep="^git-svn-id: \(${svn_url_pattern#??}\)" 2>/dev/null))
        if [[ 0 -ne ${#svn_upstream[@]} ]]; then
            svn_upstream=${svn_upstream[ ${#svn_upstream[@]} - 2 ]}
            svn_upstream=${svn_upstream%@*}
            local n_stop="${#svn_remote[@]}"
            for ((n=1; n <= n_stop; n++)); do
                svn_upstream=${svn_upstream#${svn_remote[$n]}}
            done

            if [[ -z "$svn_upstream" ]]; then
                # default branch name for checkouts with no layout:
                upstream=${GIT_SVN_ID:-git-svn}
            else
                upstream=${svn_upstream#/}
            fi
        elif [[ "svn+git" = "$upstream" ]]; then
            upstream="@{upstream}"
        fi
        ;;
    esac

    aheadBy=0
    behindBy=0
    # Find how many commits we are ahead/behind our upstream
    if [ -z "$legacy" ]; then
        IFS=$' \t\n' read -r behindBy aheadBy <<< "`git rev-list --count --left-right $upstream...HEAD 2>/dev/null`"
    else
        # produce equivalent output to --count for older versions of git
        while IFS=$' \t\n' read -r commit; do
            case "$commit" in
            "<*") (( behindBy++ )) ;;
            ">*") (( aheadBy++ ))  ;;
            esac
        done <<< "`git rev-list --left-right $upstream...HEAD 2>/dev/null`"
    fi
}

write_prompt() {
    printf --
}
