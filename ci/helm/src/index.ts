// eslint-disable-next-line @typescript-eslint/no-floating-promises

import * as core from "@actions/core";
import * as nix from "./nix";
import * as github from "@actions/github";

export async function run(args: {
  deploymentAttrPath: string;
  target: string;
  action: string;
  targetsToDiff: string;
}): Promise<void> {
  try {
    const commentMarker = `<!-- nix-toolbox-helm-diff ${args.deploymentAttrPath} -->`;
    const targetsToDiff = args.targetsToDiff.split(",");
    const context = github.context;
    const pr = context.payload.pull_request;

    if (pr) {
      const targetsDiff = targetsToDiff.map((it) =>
        nix.runAction(args.deploymentAttrPath, it, "plan"),
      );
      const prNumber = pr?.number ?? 0;
      const octokit = github.getOctokit(core.getInput("GITHUB_TOKEN"));

      const comments = await octokit.rest.issues.listComments({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: prNumber,
      });

      const commentToUpdate = comments.data.find((it) =>
        it.body?.includes(commentMarker),
      );

      const comment =
        commentMarker +
        (await Promise.all(targetsDiff))
          .map(
            (it, i) =>
              `<details><summary><code>${args.deploymentAttrPath}.${targetsToDiff[i]}</code> would change:</summary>\n\n\`\`\`diff\n${it}\n\`\`\`\n</details>`,
          )
          .join("\n");

      if (commentToUpdate) {
        console.log("update comment");
        const a = await octokit.rest.issues.updateComment({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: prNumber,
          comment_id: commentToUpdate.id,
          body: comment,
        });
        console.log(a);
      } else {
        console.log("create comment");
        await octokit.rest.issues.createComment({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: prNumber,
          body: comment,
        });
      }
    } else if (args.target && args.action) {
      nix.runAction(args.deploymentAttrPath, args.target, args.action);
    } else {
      console.info("Nothing to do");
    }
  } catch (error) {
    console.error(error);
    if (error instanceof Error) core.setFailed(error.message);
    if (error instanceof String) core.setFailed(error as string);
  }
}

run({
  deploymentAttrPath: core.getInput("deploymentAttrPath", { required: true }),
  target: core.getInput("target"),
  action: core.getInput("action"),
  targetsToDiff: core.getInput("targetsToDiff"),
});
