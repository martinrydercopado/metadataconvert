import { api } from "lwc";
import LightningModal from "lightning/modal";
import { NavigationMixin } from "lightning/navigation";

import jobProgress from "@salesforce/apex/JobStartAndTrack.jobProgress";
import executeJob from "@salesforce/apex/JobStartAndTrack.executeJob";

export default class JobStatus extends LightningModal {
    @api recordId;

    isInitialized = false;
    entries = [];
    pollProcessId;
    pollStartTime;

    jobLink = "";
    jobName = "";
    jobStatus = "";
    jobError = "";
    jobDateTime;
    templateName = "";

    // read the job progress and assign the UI properties
    refreshJobProgress() {
        this.entries = [];
        let jobExecutionIds = [];

        if (this.jobExecutionId) {
            jobExecutionIds.push(this.jobExecutionId);
        }

        jobProgress({ jobExecutionIds: jobExecutionIds })
            .then((results) => {
                for (const r of results.toReversed()) {
                    const s = r.copado__JobStep__r;
                    const e = s?.copado__JobExecution__r;
                    this.jobLink = "/" + e?.Id;
                    this.jobName = e?.Name;
                    this.jobStatus = e?.copado__Status__c;
                    this.templateName = e?.copado__Template__r?.Name;
                    this.jobDateTime = e?.CreatedDate;
                    this.jobError = e?.copado__ErrorMessage__c;

                    let entry = {
                        datetime: r.CreatedDate,
                        step: s?.Name,
                        status: e?.copado__Status__c,
                        link: "/" + r.Id,
                        logId:
                            r.ContentDocumentLinks &&
                            r.ContentDocumentLinks.length > 0
                                ? r.ContentDocumentLinks[0].ContentDocumentId
                                : null
                    };

                    this.entries.push(entry);

                    for (const h of r.Histories.toReversed()) {
                        if (!h.NewValue) continue;

                        entry = {
                            datetime: h.CreatedDate,
                            status: h.NewValue
                        };

                        this.entries.push(entry);
                    }
                }

                for (const e of this.entries) {
                    console.debug("-", JSON.stringify(e));
                }

                // if the job is running, poll the UI
                if (
                    ["Not Started", "In Progress"].indexOf(this.jobStatus) > -1
                ) {
                    this.pollStartTime =
                        this.pollStartTime || new Date().getTime();
                    let elapsed =
                        (new Date().getTime() - this.pollStartTime) / 1000;

                    let interval =
                        elapsed > 3600
                            ? 60
                            : elapsed > 1800
                            ? 30
                            : elapsed > 300
                            ? 10
                            : 5;
                    this.pollProcessId = window.setTimeout(
                        () => this.refreshJobProgress(),
                        interval * 1000
                    );
                }
            })
            .catch((error) => {
                console.error(
                    "There was an error trying to read the progress of the job. Will retry.",
                    error
                );
            });
    }

    renderedCallback() {
        if (!this.isInitialized) {
            console.debug(this.recordId);

            executeJob({
                userStoryId: this.recordId
            })
                .then((executionId) => {
                    this.jobExecutionId = executionId;
                    console.log(executionId);
                    this.isInitialized = true;
                    this.refreshJobProgress();
                })
                .catch((error) => {
                    // TODO: handle errors properly
                    console.error(error);
                });
        }
    }

    disconnectedCallback() {
        if (this.pollProcessId) {
            window.clearTimeout(this.pollProcessId);
            this.pollProcessId = null;
        }
    }

    navigateToPage(event) {
        if (!event.target.dataset.id) return;
        // navigate to the next screen

        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: event.target.dataset.id,
                actionName: "view"
            }
        });
    }
}