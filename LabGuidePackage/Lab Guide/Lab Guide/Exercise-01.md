# Exercise 01: Verify Sora 2 deployment and open the Video playground

### Estimated Duration: 12 minutes

## Scenario

Your sustainability-focused marketing team is preparing launch assets for an eco-friendly reusable water bottle. Before you start prompting Sora 2, you need to confirm that the lab-provisioned Microsoft Foundry environment is available, verify the prepared Sora 2 deployment named `sora2-campaign`, and open it in the Video playground.

## Overview

In this exercise, you will sign in to Microsoft Foundry, select the prepared project or resource for this lab, verify that the Sora 2 deployment exists, and open the deployment in the Video playground. The deployment is already provisioned by the lab environment, so you will not create or modify model deployments in this exercise.

## Objectives

- Task 1: Sign in to Microsoft Foundry
- Task 2: Select the prepared project or resource
- Task 3: Verify the `sora2-campaign` deployment
- Task 4: Open Sora 2 in the Video playground and validate the exercise

## Task 1: Sign in to Microsoft Foundry

In this task, you will sign in to the Microsoft Foundry portal with your CloudLabs credentials.

1. On the Lab VM, open Microsoft Edge.

2. Browse to <https://ai.azure.com>.

3. When prompted, sign in with the following lab credentials:

   - Username: <inject key="AzureAdUserEmail"></inject>
   - Password: <inject key="AzureAdUserPassword"></inject>

4. If a directory, tenant, or account picker appears, choose the account associated with tenant <inject key="TenantID"></inject> and subscription <inject key="SubscriptionID"></inject>.

5. If prompted to stay signed in, select **Yes**.

6. Wait for the Microsoft Foundry landing page to load.

> [!Tip]
> If the browser opens a previous session or another account, use an InPrivate window and sign in again with the CloudLabs credentials above.

## Task 2: Select the prepared project or resource

In this task, you will locate the Foundry project or Azure OpenAI resource that was prepared for this lab run.

1. In Microsoft Foundry, confirm that you are in the correct tenant and subscription for this lab.

2. If Microsoft Foundry prompts you to select a project, select the prepared Sora campaign project for this lab run.

3. If you are on the Foundry home page, select **Build** from the upper-right navigation.

4. If more than one project or resource is listed, use the project/resource associated with your CloudLabs deployment id **sora-campaign-<inject key="DeploymentID" enableCopy="false"/>**.

5. If you need help identifying the prepared resource, open `C:\LabFiles\SoraCampaign\deployment-info.json` on the Lab VM and compare the listed subscription, resource group, Foundry resource, project, and deployment name with the items shown in Microsoft Foundry.

> [!Important]
> Do not create a new project, resource, or deployment for this exercise. The lab environment already provisions the Sora 2 deployment named `sora2-campaign`.

## Task 3: Verify the `sora2-campaign` deployment

In this task, you will confirm that the Sora 2 deployment is present and ready to use.

1. In the left navigation, select **Models**.

2. Review the deployed models list.

3. Locate the deployment named `sora2-campaign`.

4. Select the `sora2-campaign` deployment to open its details page.

5. Confirm that the deployment details identify the model as Sora 2, Sora-2, or `sora-2`.

6. Confirm that the deployment is associated with the prepared Foundry resource or project for this lab.

> [!Note]
> Microsoft Foundry and Sora 2 features are in active preview. Depending on the portal build, the navigation label might appear as **Models**, **Models + endpoints**, **Deployments**, or a similar model management label. If you see **Models + endpoints**, use that page to find the existing `sora2-campaign` deployment. If you see a **Deploy base model** or **Deploy model** button, do not use it in this lab because the deployment already exists.

## Task 4: Open Sora 2 in the Video playground and validate the exercise

In this task, you will open the verified deployment in the Video playground and run the exercise validation.

1. On the `sora2-campaign` deployment page, select **Open in playground**.

2. Confirm that Microsoft Foundry opens a playground for the Sora 2 video model.

3. Verify that the page includes the video prompt input area and generation controls such as duration, aspect ratio, or similar video settings.

4. Do not select **Generate** yet. You will create campaign videos in Exercise 2.

5. Keep the Video playground open for the next exercise.

> [!Tip]
> For a video model such as Sora 2, Microsoft Foundry opens the Video playground experience from the model playground. If you land on a general model page instead, select **Open in playground** again or return to **Build** > **Models** and reopen the `sora2-campaign` deployment.

## Expected result

You are signed in to Microsoft Foundry, the prepared project or resource for this CloudLabs deployment is selected, the Sora 2 deployment named `sora2-campaign` is visible, and the deployment is open in the Video playground ready for prompting.

## Validation

After you verify that `sora2-campaign` is open in the Video playground, use the CloudLabs validation control for this exercise. The validation checks that the expected Sora 2 deployment exists in the prepared Azure OpenAI or Foundry resource.

<validation step="Sora 2 deployment exists"/>

## Summary

In this exercise, you confirmed access to the prepared Microsoft Foundry environment, verified the pre-provisioned `sora2-campaign` Sora 2 deployment, and opened it in the Video playground. You are now ready to generate and refine the first campaign video asset.