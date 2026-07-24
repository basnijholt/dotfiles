# slurm.sh - meant to be sourced in .bash_profile/.zshrc

if [[ $- == *i* ]] && command -v squeue &> /dev/null; then
    export SCHEDULER_SYSTEM="SLURM"
    alias squeue='squeue --Format="jobid:12,partition:15,name:35,username:20,state:8,timeused:10,timelimit:12,numnodes:6,reasonlist"'
    alias jobs='squeue -u $USER'
    alias release='jobs | grep held | awk "{print $1}" | while read line; do scontrol release ${line} ; done'
    alias checkfailed="sacct -u $USER --format=Jobid,Jobname,state,nodelist | grep FAILED"
    alias release_all="jobs | grep 'launch failed requeued held' | awk ' NR>1 {print $1}' | xargs -I {} scontrol release {}"
    sshnode () { ssh -o StrictHostKeyChecking=no `scontrol show node "$@" | grep NodeAddr | awk '{print $1;}' | cut -d "=" -f 2`; }

    status () {
        for f in *out; do
            grep "status" $f | tail -1
        done
    }
    # Based on https://unix.stackexchange.com/questions/417426/best-way-to-cancel-all-the-slurm-jobs-from-shell-command-output
    scancel_grep () {
        squeue -u $USER | grep $1 | awk '{print $1}' | xargs -n 1 scancel
    }
    export TMPDIR=~/.tmp/  # for VScode ssh tmp files
    mkdir -p "$TMPDIR"     # zellij (and others) panic if TMPDIR does not exist
fi
