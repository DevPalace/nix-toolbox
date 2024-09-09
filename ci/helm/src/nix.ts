import { spawn } from "child_process";

// apply, plan and destroy are the default actions, `string` is left for the future once we add custom actions
export type Action = "apply" | "plan" | "destroy" | string;

export const runAction = async (
  deployment: string,
  target: string,
  action: Action,
): Promise<string> => {
  const extraArgs = action === "apply" ? ["--", "--yes"] : [];
  return spawnPromise("nix", [
    "run",
    `.#${deployment}.${target}.${action}`,
    ...extraArgs,
  ]);
};

const spawnPromise = (cmd: string, args: ReadonlyArray<string>) =>
  new Promise<string>((resolve, reject) => {
    const cp = spawn(cmd, args);
    const error: string[] = [];
    const stdout: string[] = [];

    cp.stdout.on("data", (data) => {
      stdout.push(data.toString());
    });

    cp.on("error", (e) => {
      error.push(e.toString());
    });

    cp.on("close", () => {
      if (error.length) reject(error.join(""));
      else resolve(stdout.join(""));
    });
  });
