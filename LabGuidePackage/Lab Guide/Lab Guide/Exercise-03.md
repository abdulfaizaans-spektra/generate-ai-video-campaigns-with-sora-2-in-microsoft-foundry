# Exercise 03: Create an Image-to-Video Variation and Evaluate Campaign Readiness

### Estimated Duration: 25 minutes

## Scenario

Your marketing team has a refined text-generated concept for the EcoSip reusable water bottle campaign. Now you need tighter visual control: the product should resemble the approved bottle reference image rather than a fully invented bottle. In this exercise, you will use the supplied product mockup as an image reference in the Sora 2 Video playground, generate an image-to-video variation, save evidence, and select the campaign asset that is most ready for review.

## Overview

You will locate the supplied rights-cleared product image on the Lab VM, upload it to the Sora 2 Video playground as a reference image, generate a short vertical campaign video, and complete the campaign evaluation scorecard in the worksheet. If time remains, you can try a second image only if you have rights to use it and it meets the image-use rules in this exercise.

## Objectives

- Task 1: Review the supplied reference image and Responsible AI image-use rules
- Task 2: Generate an image-to-video campaign variation in the Video playground
- Task 3: Save campaign evidence and optionally try a rights-cleared image
- Task 4: Complete the campaign scorecard and select the preferred asset
- Task 5: Run the validation for the completed image variation and evaluation

## Task 1: Review the supplied reference image and Responsible AI image-use rules

In this task, you will confirm the reference image is available on the Lab VM and review the restrictions that apply before you upload image inputs to Sora 2.

1. On the Lab VM, open **File Explorer**.

2. Browse to the following folder:

   ```text
   C:\LabFiles\SoraCampaign\Images
   ```

3. Confirm that the following file exists:

   ```text
   EcoBottle-Reference.png
   ```

4. Open `EcoBottle-Reference.png` and briefly inspect it. It should show a rights-cleared product mockup and should not contain human faces.

5. Keep the image folder open or note the full image path for the upload step:

   ```text
   C:\LabFiles\SoraCampaign\Images\EcoBottle-Reference.png
   ```

6. Review these Responsible AI image-use reminders before continuing:

   - Use only images that you or the lab environment have rights to use.
   - Do not upload images containing human faces. Sora 2 currently rejects input images with human faces.
   - Do not prompt for real people or public figures.
   - Do not request copyrighted characters, copyrighted music, logos, trademarks, or brand impersonation.
   - Keep the campaign suitable for all audiences.
   - If a generation is rejected, revise the prompt toward neutral product, environment, camera, lighting, and motion details.

> [!Important]
> Sora 2 supports image-to-video/reference inputs, but the image must still pass content moderation. Microsoft Foundry also filters unsafe prompts and generated content in the Video playground.

## Task 2: Generate an image-to-video campaign variation in the Video playground

In this task, you will upload the supplied product image as the reference input and generate an image-guided campaign variation.

1. Return to Microsoft Foundry at:

   ```text
   https://ai.azure.com
   ```

2. If you are prompted to sign in again, use your lab credentials:

   - Username: <inject key="AzureAdUserEmail"></inject>
   - Password: <inject key="AzureAdUserPassword"></inject>

3. Open the prepared Foundry project you used in the previous exercises.

4. Open the deployed Sora 2 model in the **Video playground**. Depending on the current preview UI, you may get there from **Build** > **Models**, **Models + endpoints**, the deployed `sora-2` model page, or **Open in playground**.

5. In the Video playground prompt area, look for the image attachment or upload control. Microsoft Foundry documents that, for video models that support image-to-video generation, you can upload an image attachment to the prompt bar.

6. Upload the supplied reference image:

   ```text
   C:\LabFiles\SoraCampaign\Images\EcoBottle-Reference.png
   ```

7. Set the generation controls to a short social campaign format. Use the closest available options in the preview UI:

   | Setting | Recommended value |
   |---|---|
   | Duration | 4 seconds |
   | Orientation / aspect ratio | Vertical or portrait |
   | Resolution / size | A supported portrait option, such as 720x1280, if shown |
   | Variants | 1, if the UI asks |

> [!Note]
> Sora 2 generation is asynchronous. The playground submits a generation job, waits while it runs, and then displays the finished result. Short 4-second outputs keep the lab within the expected time window.

8. Copy the following image-to-video prompt and paste it into the Video playground prompt box:

   ```text
   Use the reference image as the product anchor. Create a 4-second vertical launch video for EcoSip, an eco-friendly reusable water bottle. Keep the bottle shape, color, and overall product identity consistent with the reference image. Place it on a bright kitchen counter with herbs, a reusable shopping bag, and soft morning light. Add gentle camera movement from left to right, shallow depth of field, clean sustainable lifestyle aesthetic, realistic product advertising style, no people, no faces, no trademarks, no copyrighted music, suitable for all audiences.
   ```

9. Select **Generate**.

10. Wait for the video generation to finish. Generation can take a few minutes depending on service load and selected settings.

11. If the generation fails because of a content or image issue, make one safe revision and try again. For example, remove any ambiguous terms and keep the request focused on a product on a kitchen counter with lighting and camera movement.

12. When the generated video appears, play it once and check whether it:

   - Preserves the general product identity from the reference image.
   - Uses the requested kitchen counter scene.
   - Avoids people, faces, trademarks, and unsafe content.
   - Has smooth enough camera motion for a short social ad.

> [!Tip]
> If the playground reports an image size or format issue, use the built-in upload/crop option if available. If you use your own image later, prefer PNG, JPEG, or WebP and choose a size/orientation that matches the selected video output as closely as possible.

## Task 3: Save campaign evidence and optionally try a rights-cleared image

In this task, you will save the image-guided result before it expires and capture the prompt details in the worksheet.

1. In File Explorer, open the evidence folder:

   ```text
   C:\LabFiles\SoraCampaign\Evidence
   ```

2. Download the generated video from the Video playground if the UI provides a download option. Save it in the evidence folder with this filename:

   ```text
   ecosip-image-variation.mp4
   ```

3. If the download option is not available, take a screenshot of the completed video result and save it in the evidence folder with this filename:

   ```text
   ecosip-image-variation-screenshot.png
   ```

> [!Important]
> Generated videos in the Video playground are retained for a limited time. Download the video or save screenshot evidence before the end of the lab.

4. Open the worksheet file:

   ```text
   C:\LabFiles\SoraCampaign\Campaign-Worksheet.md
   ```

5. In the **Image-to-video prompt** section, paste the prompt you used.

6. In the **Image-guided output observations** or nearest available notes section, record two or three short observations. Include at least:

   - Whether the bottle stayed visually consistent with the reference image.
   - Whether the scene matched the sustainability campaign brief.
   - Any issue you noticed, such as product distortion, camera jitter, or mismatched setting.

7. Save the worksheet.

8. Optional, if you have time remaining: try one additional image-to-video run with your own image only if all of the following are true:

   - You own the image or have permission to use it for this lab.
   - The image does not contain human faces or identifiable people.
   - The image does not include logos, trademarks, copyrighted characters, or restricted content.
   - The image is PNG, JPEG, or WebP.
   - The image orientation is close to the selected video output, such as portrait for a vertical video.

9. If you run the optional image, save the additional output or screenshot to the evidence folder using a clear filename, such as:

   ```text
   ecosip-optional-image-variation.mp4
   ```

## Task 4: Complete the campaign scorecard and select the preferred asset

In this task, you will evaluate the baseline, refined text prompt, and image-guided variation against practical campaign criteria.

1. In `C:\LabFiles\SoraCampaign\Campaign-Worksheet.md`, find the campaign evaluation or scorecard section.

2. Score each generated asset from 1 to 5 for the following criteria, where 1 means weak and 5 means strong:

   | Criterion | What to look for |
   |---|---|
   | Visual quality | Clear, appealing, coherent frames with minimal artifacts |
   | Prompt adherence | Follows subject, setting, action, lighting, duration, and format instructions |
   | Product / brand consistency | Bottle appearance and EcoSip concept remain consistent |
   | Camera movement and pacing | Motion is smooth and appropriate for a short ad |
   | Sustainability campaign fit | Feels aligned with reusable, eco-friendly lifestyle messaging |
   | Short social ad suitability | Works as a quick vertical launch asset |
   | Responsible AI / content safety compliance | No faces, public figures, copyrighted characters, trademarks, unsafe content, or adult-only content |

3. Compare the three main outputs from the lab:

   - Baseline text-to-video result
   - Refined structured text-to-video result
   - Image-guided variation from this exercise

4. In the worksheet, complete the final selection fields:

   - **Preferred video:** baseline, refined text prompt, or image-guided variation
   - **Why it best fits the campaign:** one or two sentences
   - **One change before production use:** one practical improvement, such as a tighter product shot, cleaner background, stronger lighting, or a clearer end frame

5. Save the worksheet.

### Expected result

You should now have an image-guided Sora 2 campaign variation saved as a downloaded video or screenshot, plus a completed worksheet that includes the image-to-video prompt, output observations, scorecard, final preferred asset, rationale, and one recommended improvement.

## Task 5: Run the validation for the completed image variation and evaluation

In this task, you will trigger the CloudLabs validation for Exercise 3.

1. Confirm that the evidence folder contains at least one image-variation evidence file, such as:

   ```text
   C:\LabFiles\SoraCampaign\Evidence\ecosip-image-variation.mp4
   ```

   or:

   ```text
   C:\LabFiles\SoraCampaign\Evidence\ecosip-image-variation-screenshot.png
   ```

2. Confirm that `C:\LabFiles\SoraCampaign\Campaign-Worksheet.md` includes:

   - The image-to-video prompt.
   - Notes about the image-guided output.
   - A completed scorecard or ratings.
   - A preferred video selection and rationale.

3. Run the validation step below.

<validation step="Image variation and evaluation complete"/>

## Summary

You used a rights-cleared product reference image to guide Sora 2 image-to-video generation in Microsoft Foundry, saved evidence before the generated output expires, and evaluated all campaign assets using a practical readiness scorecard. Your final selection identifies which generated clip is best suited for the EcoSip launch campaign and what should be improved before production use.
