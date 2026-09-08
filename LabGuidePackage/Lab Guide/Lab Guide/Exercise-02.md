# Exercise 02: Generate and Refine a Text-to-Video Campaign Clip

### Estimated Duration: 20 minutes

## Scenario

The sustainability marketing team needs a first social-media-ready campaign clip for an eco-friendly reusable water bottle. In this exercise, you will use the pre-provisioned Sora 2 deployment in Microsoft Foundry to compare a simple baseline prompt with a more structured production prompt, then save evidence of both attempts for campaign review.

## Overview

You will use the Microsoft Foundry Video playground with the `sora2-campaign` deployment that you created in Exercise 1. First, you will generate a baseline video from a deliberately broad prompt. Next, you will refine the concept by adding subject, action, environment, camera movement, lighting, mood, duration, and safety constraints. Sora 2 video generation runs asynchronously, so each generation can take several minutes before the result appears.

## Objectives

- Task 1: Open the Sora 2 deployment in the Video playground
- Task 2: Generate a baseline text-to-video campaign clip
- Task 3: Generate a refined structured-prompt campaign clip
- Task 4: Save prompt and output evidence
- Task 5: Validate your campaign prompt evidence

## Task 1: Open the Sora 2 deployment in the Video playground

In this task, you will return to Microsoft Foundry and confirm that you are using the correct Sora 2 deployment before generating campaign assets.

1. From the Lab VM, open a browser and go to <https://ai.azure.com>.

2. If you are prompted to sign in, use the lab credentials:

   - Username: <inject key="AzureAdUserEmail"></inject>
   - Password: <inject key="AzureAdUserPassword"></inject>

3. Confirm that you are in the correct lab subscription and tenant:

   - Subscription: <inject key="SubscriptionID"></inject>
   - Tenant: <inject key="TenantID"></inject>
   - Lab deployment: **Sora Campaign <inject key="DeploymentID" enableCopy="false"/>**

4. In Microsoft Foundry, select the prepared project or resource that you used in Exercise 1.

5. From the left navigation, open the model deployment area. Depending on the current preview UI, this area might be labeled **Models**, **Models + endpoints**, or similar.

6. Select the deployed Sora 2 model deployment named `sora2-campaign`.

7. Select **Open in playground**. Foundry should open the **Video playground** for the deployed Sora 2 model.

> [!Note]
> The Microsoft Foundry preview UI can change. If you do not see the exact label in a step, look for the deployed model named `sora2-campaign`, then choose the option that opens the model in the playground.

## Task 2: Generate a baseline text-to-video campaign clip

In this task, you will create a first-pass campaign clip from a short, vague prompt. This baseline helps you observe how much the model infers when you do not provide production details.

1. In the Video playground prompt box, paste the following baseline prompt:

   ```text
   Make a short promotional video for an eco-friendly reusable water bottle.
   ```

2. Set the generation controls to the shortest practical values available in the UI:

   - **Duration / seconds**: choose **4 seconds** if available.
   - **Aspect ratio / orientation / size**: choose **portrait**, **vertical**, or **720×1280** if available.
   - **Number of outputs / variants**: choose **1** if the option is shown.

> [!Tip]
> Sora 2 supports multiple durations and resolutions, but this lab uses a short 4-second vertical clip to keep the exercise within the 60-minute lab window and to target a typical short-form social campaign format.

3. Select **Generate**.

4. Wait for the generation to complete. Video generation is asynchronous; Microsoft Learn notes that generation typically takes **1 to 5 minutes**, depending on the selected settings.

5. While the job is running, do not repeatedly select **Generate**. Sora 2 has concurrency limits, and starting extra jobs can slow your lab progress.

6. When the result appears, play the generated video in the playground.

7. Observe the output and note the following:

   - Did the video clearly show a reusable water bottle?
   - Did it communicate sustainability?
   - Were the camera motion and scene composition useful for a launch campaign?
   - Were there artifacts, inconsistent objects, distracting motion, or unclear brand focus?

8. If the prompt is rejected by content filtering, revise it to remain neutral and product-focused. Avoid real people, public figures, faces, copyrighted characters, trademarks, logos, unsafe content, and copyrighted music.

> [!Important]
> Sora 2 generation is subject to Azure OpenAI and Azure AI Content Safety filtering. For this lab, keep prompts suitable for all audiences and focused on a fictional product scene with no people, no faces, no logos, and no copyrighted references.

## Task 3: Generate a refined structured-prompt campaign clip

In this task, you will improve the prompt by adding concrete production details. The goal is to make the output more useful as a product launch asset.

1. In the Video playground prompt box, replace the baseline prompt with the following refined prompt:

   ```text
   Create a 4-second vertical promotional video for an eco-friendly reusable water bottle called EcoSip. Show a sleek matte-green bottle standing on a wooden café table beside a small plant. Morning sunlight comes through a window, with soft natural shadows and a clean sustainable lifestyle mood. Start with a close-up of condensation on the bottle, then use a slow camera push-in as the bottle remains centered. Modern minimal product-ad style, realistic lighting, no people, no logos, no copyrighted music, suitable for all audiences.
   ```

2. Confirm the generation controls are still set for a short vertical output:

   - **Duration / seconds**: **4 seconds** if available.
   - **Aspect ratio / orientation / size**: **portrait**, **vertical**, or **720×1280** if available.
   - **Number of outputs / variants**: **1** if shown.

3. Select **Generate**.

4. Wait for the generation to complete. Expect the job to move through background processing before the video appears in the playground.

5. When the refined result appears, play the generated video.

6. Compare the refined clip against the baseline clip. Look specifically for improvements in:

   - Product prominence: the reusable bottle should be the clear subject.
   - Scene control: café table, small plant, sunlight, and sustainable lifestyle cues.
   - Camera motion: slow push-in or similar controlled movement.
   - Prompt adherence: no people, no logos, no copyrighted music, and suitable-for-all-audiences content.
   - Campaign usefulness: whether the output could plausibly be reviewed by a marketing team.

> [!Note]
> Structured prompts generally work better when they are single-purpose and include the shot type, subject, action, setting, lighting, and desired camera motion. Do not overload the prompt with conflicting scene changes or complex timing.

## Task 4: Save prompt and output evidence

In this task, you will save the required evidence files to the Lab VM. Generated videos are retained for a limited time in the service, so save evidence before you leave the lab.

1. Open File Explorer and go to `C:\LabFiles\SoraCampaign`.

2. Open `Campaign-Worksheet.md` in Notepad or Visual Studio Code.

3. Save a working copy of the worksheet into the evidence folder:

   - Source file: `C:\LabFiles\SoraCampaign\Campaign-Worksheet.md`
   - Evidence copy: `C:\LabFiles\SoraCampaign\Evidence\Campaign-Worksheet.md`

4. In `C:\LabFiles\SoraCampaign\Evidence\Campaign-Worksheet.md`, complete or update the following sections:

   - **Deployment name**: `sora2-campaign`
   - **Baseline prompt**: paste the baseline prompt from Task 2.
   - **Baseline observations**: write 2–3 bullets about what worked and what was missing.
   - **Refined prompt**: paste the structured prompt from Task 3.
   - **Refined observations**: write 2–3 bullets comparing prompt adherence, motion, lighting, and campaign fit.

5. Save the worksheet.

6. Download the baseline video from the Video playground if a **Download** option is available. Save it as:

   `C:\LabFiles\SoraCampaign\Evidence\baseline-text-video.mp4`

7. Download the refined video from the Video playground if a **Download** option is available. Save it as:

   `C:\LabFiles\SoraCampaign\Evidence\refined-text-video.mp4`

8. If the Video playground does not show a download option, save screenshots instead:

   - Use **Windows key + Shift + S** to capture the baseline result and save it as `C:\LabFiles\SoraCampaign\Evidence\baseline-text-video-screenshot.png`.
   - Capture the refined result and save it as `C:\LabFiles\SoraCampaign\Evidence\refined-text-video-screenshot.png`.

9. Confirm that `C:\LabFiles\SoraCampaign\Evidence` contains at least:

   - `Campaign-Worksheet.md`
   - One baseline video or screenshot evidence file
   - One refined video or screenshot evidence file

> [!Important]
> Microsoft Learn notes that videos generated in the Video playground are retained for **24 hours**. Download videos or save screenshots locally before ending the lab.

## Task 5: Validate your campaign prompt evidence

In this task, you will run the lab validation for Exercise 2.

1. Confirm the evidence folder exists at `C:\LabFiles\SoraCampaign\Evidence`.

2. Confirm that your worksheet includes both prompt sections:

   - Baseline prompt
   - Refined prompt

3. Confirm that at least one video or screenshot evidence file from your text-to-video work is present in the evidence folder.

4. Run the validation below.

<validation step="Campaign prompt evidence saved"/>

## Expected Result

By the end of this exercise, you should have two Sora 2 text-to-video campaign attempts: a baseline clip from a broad prompt and a refined clip from a structured production-style prompt. Your evidence folder should include the completed worksheet and downloaded videos or screenshots that prove you generated and reviewed the outputs.

## Summary

In this exercise, you used the Microsoft Foundry Video playground to generate and refine a sustainable product launch video with Sora 2. You observed how a vague prompt compares with a structured prompt, used short vertical settings appropriate for social campaign review, waited for asynchronous generation to complete, and saved local evidence for validation and later evaluation.