import tl = require('azure-pipelines-task-lib/task');

async function run() {
    try {
        const ReleaseVersion: string | undefined = tl.getInput('ReleaseVersion');
        const FixedVersion: string | undefined = tl.getInput('FixedVersion');
        
        var args = [__dirname + "\\PWSHUpdater.ps1"];
        
        // we need to get the verbose flag passed in as script flag
        var verbose = (tl.getVariable("System.Debug") === "true");
        if (verbose) {
            args.push("-Verbose");
        }

        // find the executeable
        let executable = "pwsh";
        if (tl.getVariable("AGENT.OS") === "Windows_NT") {
            executable = "powershell.exe";
        }
        console.log(`Using executable '${executable}'`);

        if (FixedVersion) {
            // Fixed version is set. 
            args.push("-FixedVersion");
            args.push(FixedVersion);
        }
        else if (ReleaseVersion) {
            // ReleaseVersion is set. 
            args.push("-ReleaseVersion");
            args.push(ReleaseVersion);
        }

        
        console.log(`${executable} ${args.join(" ")}`);

        var spawn = require("child_process").spawn, child;
        child = spawn(executable, args);
        child.stdout.on("data", function (data: { toString: () => any; }) {
            console.log(data.toString());
        });
        child.stderr.on("data", function (data: { toString: () => string; }) {        
            tl.error(data.toString());
            tl.setResult(tl.TaskResult.Failed, data.toString());
        });
        child.on("exit", function () {
            console.log("Script finished");
        });
    }
    catch (err) {
        // @ts-ignore
        tl.setResult(tl.TaskResult.Failed, err.message);
    }
}

run();
