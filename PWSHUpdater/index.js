"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const tl = require("azure-pipelines-task-lib/task");
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const ReleaseVersion = tl.getInput('ReleaseVersion');
            const FixedVersion = tl.getInput('FixedVersion');
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
            child.stdout.on("data", function (data) {
                console.log(data.toString());
            });
            child.stderr.on("data", function (data) {
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
    });
}
run();
