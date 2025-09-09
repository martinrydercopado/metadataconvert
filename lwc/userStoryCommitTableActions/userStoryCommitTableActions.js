import { LightningElement, track, wire } from "lwc";
import { MessageContext, publish, subscribe } from "lightning/messageService";
import { CurrentPageReference } from "lightning/navigation";

import getSystemPropertiesFromPipelineOfUserStory from "@salesforce/apex/SystemProperties.getSystemPropertiesFromPipelineOfUserStory";
import getChangesFromUserStory from "@salesforce/apex/GetContentDocument.getChangesFromUserStory";
import COMMIT_PAGE_COMMUNICATION_CHANNEL from "@salesforce/messageChannel/copado__CommitPageCommunication__c";
import JobStatus from "c/jobStatus";

export default class UserStoryCommitTableActions extends LightningElement {
    // loading
    _isWorking = false;
    isLoading = false;
    @track hasFlow = false;
    recordId;
    _changes;
    _sourceMemberAvailableChecked = true;
    _listOfMetadataTypesAvailable = true;
    _filtered = [];

    _SFCC_METADATA = "SFCC_METADATA_ITEMS";
    _SFCC_METADATA_DIRECTORY = "SFCC_METADATA_DIRECTORY";
    _SFCC_SITES = "SFCC_SITES";

    get showSpinner() {
        return (
            this._isWorking ||
            this._sourceMemberAvailableChecked === false ||
            this._listOfMetadataTypesAvailable === false
        );
    }

    @wire(MessageContext)
    _context;

    @wire(CurrentPageReference)
    getParameters(pageReference) {
        if (pageReference && pageReference.state) {
            this.recordId = pageReference.state.copado__recordId;
        }
    }

    connectedCallback() {
        this._subscribeToMessageService();
    }

    _subscribeToMessageService() {
        subscribe(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, (message) =>
            this._handleCommitPageCommunicationMessage(message)
        );
    }

    _handleCommitPageCommunicationMessage(message) {
        this._performWithProgress(() => {
            try {
                switch (message.type) {
                    case "request":
                        // console.log("request", JSON.stringify(message));
                        break;
                    // extension
                    case "retrievedChanges":
                    case "pulledChanges":
                        // console.log("changes", JSON.stringify(message));
                        break;
                    default:
                }
            } catch (error) {
                console.log("error", error);
            }
        });
    }

    _performWithProgress(process) {
        this.isLoading = true;
        // workaround to show spinner
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (process) {
                process();
            }
            this.isLoading = false;
        }, 0);
    }

    // TODO: fix race condition
    renderedCallback() {
        getSystemPropertiesFromPipelineOfUserStory({
            userStoryId: this.recordId,
            names: [
                this._SFCC_METADATA,
                this._SFCC_SITES,
                this._SFCC_METADATA_DIRECTORY
            ]
        })
            .then((properties) => {
                const metadata =
                    properties[this._SFCC_METADATA].split(/\r?\n/g);
                const sites = (properties[this._SFCC_SITES] || "")
                    .split(/\r?\n/g)
                    .filter((x) => x !== "");
                this._filtered = metadata.reduce((arr, meta) => {
                    if (meta.includes("<site-id>")) {
                        arr.push(
                            ...sites.map((site) => {
                                let result = meta.replace("<site-id>", site);

                                if (properties[this._SFCC_METADATA_DIRECTORY]) {
                                    result = meta.replace(
                                        "metadata/",
                                        properties[
                                            this._SFCC_METADATA_DIRECTORY
                                        ]
                                    );
                                }

                                return result;
                            })
                        );
                    } else {
                        let result = meta;

                        if (properties[this._SFCC_METADATA_DIRECTORY]) {
                            result = meta.replace(
                                "metadata/",
                                properties[this._SFCC_METADATA_DIRECTORY]
                            );
                        }

                        arr.push(result);
                    }

                    return arr;
                }, []);

                setTimeout(this.retrieveChanges(), 250);
            })
            .catch((e) => {
                console.log("apex error", e);
            });
    }

    async triggerRetrieve() {
        await JobStatus.open({
            label: "Retrieve Changes",
            recordId: this.recordId
        });

        // Might cause issues
        this.retrieveChanges();
    }

    async retrieveChanges() {
        try {
            this._isWorking = true;
            const envMetadata = await getChangesFromUserStory({
                parentId: this.recordId
            });

            const envObj = JSON.parse(envMetadata).map((e) => ({
                Operation: "Add",
                MemberName: e.n,
                MemberType: e.t,
                Directory: e.m,
                LastModifiedDate: "",
                LastModifiedByName: "",
                Category: e.c
            }));

            const allMetadataFound = this._filtered.map((file) => ({
                Operation: "Add",
                MemberName: file,
                MemberType: "xml",
                Directory: "",
                LastModifiedDate: "",
                LastModifiedByName: "",
                Category: "ccmetadata"
            }));

            console.log(allMetadataFound, envObj);

            const payload = {
                type: "retrievedChanges",
                value: [...allMetadataFound, ...envObj].sort(
                    ({ MemberName: a }, { MemberName: b }) =>
                        a < b ? -1 : a > b ? 1 : 0
                )
            };

            publish(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, payload);
        } catch (exc) {
            console.log("exception", JSON.stringify(exc));
        } finally {
            this._isWorking = false;
        }
    }
}