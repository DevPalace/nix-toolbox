// eslint-disable-next-line @typescript-eslint/no-floating-promises

import * as core from "@actions/core";
import * as nix from "./nix";

/**
 * The main function for the action.
 * @returns {Promise<void>} Resolves when the action is complete.
 */
export async function run(args: {
  deploymentAttrPath: string;
  target: string;
  action: string;
}): Promise<void> {
  try {
    nix.runAction(args.deploymentAttrPath, args.target, args.action);
  } catch (error) {
    console.error(error);
    if (error instanceof Error) core.setFailed(error.message);
    if (error instanceof String) core.setFailed(error as string);
  }
}

run({
  deploymentAttrPath: core.getInput("deploymentAttrPath"),
  target: core.getInput("target"),
  action: core.getInput("action"),
});
