import tl = require('azure-pipelines-task-lib/task');

async function run() {
    try {
        const ReleaseVersion: string | undefined = tl.getInput('ReleaseVersion', true);
        const FixedVersion: string | undefined = tl.getInput('FixedVersion', true);
        
        if (FixedVersion) {
            // Fixed version is set. 
            console.log('Trying to install fixed PowerShell version ', FixedVersion);
            // tl.setResult(tl.TaskResult.Failed, 'Bad input was given');
            // return;
        }
        else if (ReleaseVersion) {
            // ReleaseVersion is set. 
            console.log('Installing PowerShell version ', ReleaseVersion);
        }
    }
    catch (err) {
        tl.setResult(tl.TaskResult.Failed, err.message);
    }
}

run();