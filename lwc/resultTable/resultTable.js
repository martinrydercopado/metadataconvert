import { LightningElement, api, track, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { loadScript } from 'lightning/platformResourceLoader';

import jsyamllib from "@salesforce/resourceUrl/jsyamllib";
import LATEST_PUBLISHED_VERSION_FIELD from '@salesforce/schema/ContentDocumentLink.ContentDocument.LatestPublishedVersionId';
import TITLE_FIELD from '@salesforce/schema/ContentDocumentLink.ContentDocument.Title';
import VERSION_DATA_FIELD from '@salesforce/schema/ContentVersion.VersionData';

// Constants for magic numbers and strings
const DEFAULT_GROUPING = 'engine';
const OUTPUT_FILE_NAME = 'output.json';
const UNKNOWN_FILE = 'Unknown File';
const UNKNOWN_TYPE = 'Unknown';
const MAIN_DEFAULT_PATTERN = /main\/default\/([^\/]+)\/(.+)/u;
const SEVERITY_PREFIX = 'sev';

// Add severity labels map after constants
const SEVERITY_LABELS = {
    1: 'Critical',
    2: 'High',
    3: 'Moderate',
    4: 'Low',
    5: 'Info'
};

export default class ResultTable extends LightningElement {
    @api recordId;
    @track filteredJson = null;
    @track relevantFormattedJson;
    @track selectedSeverity = null;
    @track violationCounts = null;
    @track searchValue = '';

    formattedJson;
    groupBy = DEFAULT_GROUPING;
    groupByOptions = [
        { label: 'Engine/Rule', value: 'engine' },
        { label: 'Type/Filename', value: 'typefilename' }
    ];
    message = 'No Violations Found';
    result = {};
    scriptsLoaded = false;
    showTable = false;
    type;
    versionId;

    // Mapping of engine names to their short descriptions
    engineDescriptions = {
        cpd: 'Copy-Paste Detector: Finds duplicate code blocks in Apex and other supported languages.',
        eslint: 'Analyzes JavaScript and Lightning Web Components for code quality and style issues.',
        flow: 'Analyzes Salesforce Flows for best practices, security, and maintainability issues.',
        pmd: 'Performs static analysis on Apex, Visualforce. Includes the PMD AppExchange rules.',
        regex: 'Detects code patterns using regular expressions. Useful for enforcing simple, custom rules.',
        retirejs: 'Scans JavaScript libraries for known security vulnerabilities.',
        sfge: 'Salesforce Graph Engine: Advanced static analysis for security, CRUD/FLS, and data flow in Apex.'
    };

    @wire(getRelatedListRecords, {
        fields: [
            `${LATEST_PUBLISHED_VERSION_FIELD.objectApiName}.${LATEST_PUBLISHED_VERSION_FIELD.fieldApiName}`,
            `${TITLE_FIELD.objectApiName}.${TITLE_FIELD.fieldApiName}`
        ],
        parentRecordId: '$recordId',
        relatedListId: 'ContentDocumentLinks'
    })
    docLinksInfo({ data }) {
        if (data) {
            // Change the file name from where data should be fetched
            const logsDoc = data?.records?.find((doc) => getFieldValue(doc, TITLE_FIELD) === OUTPUT_FILE_NAME);

            if (logsDoc) {
                this.versionId = getFieldValue(logsDoc, LATEST_PUBLISHED_VERSION_FIELD);
            }
        }
    }

    @wire(getRecord, { fields: [VERSION_DATA_FIELD], recordId: '$versionId' })
    wiredVersion({ data }) {
        if (data) {
            const rawData = getFieldValue(data, VERSION_DATA_FIELD);
            const serializedJson = this.b64DecodeUnicode(rawData);
            const { formattedJson, type } = this.getFormattedData(serializedJson);

            if (formattedJson.length > 0) {
                this.formattedJson = formattedJson;
                this.relevantFormattedJson = formattedJson;
                this.showTable = true;
                this.type = type;
            }
        }
    }

    async connectedCallback() {
        if (!this.scriptsLoaded) {
            await loadScript(this, jsyamllib);
            this.scriptsLoaded = true;
        }
    }

    get columns() {
        if (this.type !== 'Table') {
            return [];
        }

        const allKeys = this.formattedJson.reduce((keys, item) => {
            return keys.concat(Object.keys(item));
        }, []);
        const uniqueKeys = [...new Set(allKeys)];

        return uniqueKeys.map(key => {
            return {
                fieldName: key,
                label: key.charAt(0).toUpperCase() + key.slice(1),
                type: 'text'
            };
        });
    }

    // Helper method to create engine object structure
    createEngineObject(engine, violation) {
        return {
            engine: engine,
            rules: {},
            violationCount: 0
        };
    }

    // Helper method to create rule object structure
    createRuleObject(violation) {
        return {
            engine: violation.engine,
            resource: violation.resource,
            rule: violation.rule,
            severity: violation.severity,
            tags: violation.tags,
            violations: []
        };
    }

    // Helper method to process violations and group by engine and rule
    processViolationsByEngine(violations, filterSeverity = null) {
        const engines = {};

        violations.forEach(violation => {
            // Apply severity filter if provided
            if (filterSeverity && String(violation.severity) !== String(filterSeverity)) {
                return;
            }

            if (!engines[violation.engine]) {
                engines[violation.engine] = this.createEngineObject(violation.engine, violation);
            }

            if (!engines[violation.engine].rules[violation.rule]) {
                engines[violation.engine].rules[violation.rule] = this.createRuleObject(violation);
            }

            engines[violation.engine].rules[violation.rule].violations.push(violation);
            engines[violation.engine].violationCount += 1;
        });

        return engines;
    }

    // Helper method to transform engine objects to array format
    transformEngineObjectsToArray(engines, includeKey = false) {
        return Object.values(engines).map(engineObj => {
            const baseObject = {
                description: this.engineDescriptions[engineObj.engine] || '',
                engine: engineObj.engine,
                label: `${engineObj.engine} (${engineObj.violationCount})`,
                rules: Object.values(engineObj.rules).map(ruleObj => ({
                    ...ruleObj,
                    tagsString: Array.isArray(ruleObj.tags) ? ruleObj.tags.join(', ') : '',
                    severityLabel: `${ruleObj.severity} (${SEVERITY_LABELS[ruleObj.severity] || ''})`
                })),
                violationCount: engineObj.violationCount
            };

            if (includeKey) {
                baseObject.key = engineObj.engine;
                baseObject.rules = Object.values(engineObj.rules).map(ruleObj => ({
                    key: ruleObj.rule,
                    label: `${ruleObj.rule} (${ruleObj.violations.length})`,
                    resource: ruleObj.resource,
                    severity: ruleObj.severity,
                    tagsString: Array.isArray(ruleObj.tags) ? ruleObj.tags.join(', ') : '',
                    violations: ruleObj.violations,
                    severityLabel: `${ruleObj.severity} (${SEVERITY_LABELS[ruleObj.severity] || ''})`
                }));
            }

            return baseObject;
        });
    }

    get groupedByEngine() {
        const data = this.filteredJson || this.formattedJson;
        if (!data) {
            return [];
        }

        const engines = this.processViolationsByEngine(data);
        return this.transformEngineObjectsToArray(engines);
    }

    get filteredGroupedByEngine() {
        const data = this.filteredJson || this.formattedJson;
        if (!data) {
            return [];
        }

        const engines = this.processViolationsByEngine(data, this.selectedSeverity);
        return this.transformEngineObjectsToArray(engines);
    }

    get groupedByRule() {
        if (!this.formattedJson) {
            return [];
        }

        const groups = {};
        this.formattedJson.forEach(violation => {
            if (!groups[violation.rule]) {
                groups[violation.rule] = this.createRuleObject(violation);
            }
            groups[violation.rule].violations.push(violation);
        });

        return Object.values(groups);
    }

    get groupedByMetadataTypeArray() {
        // Use filteredJson if present, otherwise formattedJson
        const data = this.filteredJson || this.formattedJson;
        if (!data) {
            return [];
        }

        const filterSeverity = this.selectedSeverity;
        const metaTypeMap = {};

        data.forEach(violation => {
            if (filterSeverity && String(violation.severity) !== String(filterSeverity)) {
                return;
            }

            let metaType = UNKNOWN_TYPE;
            let fileKey = violation.file || UNKNOWN_FILE;

            if (violation.file) {
                // Since violation.file now contains the shortened path (e.g., "lwc/resultTable/resultTable.js"),
                // we need to extract the metadata type (first part) and the file key (rest)
                const pathParts = violation.file.split('/');
                if (pathParts.length >= 2) {
                    metaType = pathParts[0];
                    fileKey = pathParts.slice(1).join('/');
                } else {
                    fileKey = violation.file;
                }
            }

            if (!metaTypeMap[metaType]) {
                metaTypeMap[metaType] = {};
            }
            if (!metaTypeMap[metaType][fileKey]) {
                metaTypeMap[metaType][fileKey] = [];
            }
            metaTypeMap[metaType][fileKey].push(violation);
        });

        // Convert to array structure for template, with counts in labels
        return Object.keys(metaTypeMap).map(metaType => {
            const filesArr = Object.keys(metaTypeMap[metaType]).map(file => ({
                key: file,
                label: `${file} (${metaTypeMap[metaType][file].length})`,
                violations: metaTypeMap[metaType][file]
            }));
            const totalViolations = filesArr.reduce((sum, fileObj) => sum + fileObj.violations.length, 0);
            return {
                files: filesArr,
                key: metaType,
                label: `${metaType} (${totalViolations})`
            };
        });
    }

    get groupedViolationsArray() {
        // Use filteredJson if present, otherwise formattedJson
        const data = this.filteredJson || this.formattedJson;
        if (this.groupBy === 'engine') {
            return this.groupByEngineAndRuleArray(data);
        } else if (this.groupBy === 'typefilename') {
            // For type/filename grouping
            // Return: [{ key, label, files: [{ key, label, violations }] }]
            return this.groupedByMetadataTypeArray;
        }
        return [];
    }

    get groupedViolations() {
        if (this.groupBy === 'engine') {
            return this.groupByEngineAndRule(this.formattedJson);
        } else {
            return this.groupByFilename(this.formattedJson);
        }
    }

    get isEngineGrouping() {
        return this.groupBy === 'engine';
    }

    get isFilenameGrouping() {
        return this.groupBy === 'filename';
    }

    get isString() {
        return (this.type === 'String' && this.formattedJson);
    }

    get isTabular() {
        return (this.type === 'Table' && this.columns.length);
    }

    get isTypeFilenameGrouping() {
        return this.groupBy === 'typefilename';
    }

    get isYAML() {
        return (this.type === 'YAML' && this.formattedJson);
    }

    get recordCount() {
        return this.relevantFormattedJson?.length;
    }

    get severityLevels() {
        if (!this.violationCounts) {
            return [];
        }

        // Get the data to count from (filtered or original)
        const data = this.filteredJson || this.formattedJson;

        return Object.keys(this.violationCounts)
            .filter(key => key.startsWith(SEVERITY_PREFIX))
            .map(key => {
                const level = key.replace(SEVERITY_PREFIX, '');

                // Calculate dynamic count for this severity level
                let count = this.violationCounts[key];
                if (data && this.filteredJson) {
                    // If search is applied, count only violations of this severity in the filtered results
                    count = data.filter(violation => String(violation.severity) === String(level)).length;
                }

                // Determine button variant based on selection state
                const isSelected = this.selectedSeverity === level;
                const buttonVariant = 'brand'; // Always use brand variant, let CSS handle the styling
                const buttonClass = `severity-${level}-btn ${isSelected ? 'selected' : ''}`;

                return {
                    buttonClass: buttonClass,
                    buttonVariant: buttonVariant,
                    count: count,
                    label: `${SEVERITY_LABELS[level]} (${count})`,
                    title: `Severity ${level}: ${SEVERITY_LABELS[level]}`,
                    level
                };
            })
            .sort((a, b) => a.level - b.level);
    }

    get dynamicTotalViolations() {
        // Use filteredJson if present, otherwise formattedJson
        const data = this.filteredJson || this.formattedJson;
        if (!data) {
            return 0;
        }

        // If a severity filter is applied, count only violations of that severity
        if (this.selectedSeverity) {
            return data.filter(violation => String(violation.severity) === String(this.selectedSeverity)).length;
        }

        // If search is applied, return the count of filtered results
        if (this.filteredJson) {
            return this.filteredJson.length;
        }

        // Return total count from violationCounts if available, otherwise count from data
        return this.violationCounts?.total || data.length;
    }

    get hasActiveFilters() {
        return this.selectedSeverity !== null || this.filteredJson !== null;
    }

    get violationColumns() {
        return [
            { fieldName: 'file', label: 'File', type: 'text' },
            { fieldName: 'line', label: 'Line', type: 'number' },
            { fieldName: 'message', label: 'Message', type: 'text' }
        ];
    }

    get violationColumnsForDisplay() {
        if (this.groupBy === 'typefilename') {
            // Show Engine, Severity, Rule, Line, and Message columns in this order
            return [
                { fieldName: 'engine', label: 'Engine', type: 'text' },
                { fieldName: 'rule', label: 'Rule', type: 'text' },
                { fieldName: 'severityLabel', label: 'Severity', type: 'text' },
                { fieldName: 'line', label: 'Line', type: 'number' },
                { fieldName: 'message', label: 'Message', type: 'text' }
            ];
        }
        return this.violationColumns;
    }

    get yamlData() {
        if (this.isYAML && this.scriptsLoaded) {
            return jsyaml.dump(this.formattedJson);
        }

        return '';
    }

    b64DecodeUnicode(str) {
        return decodeURIComponent(atob(str).split('').map(function (c) {
            return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
        }).join(''));
    }

    getEngineDescription(engine) {
        return this.engineDescriptions[engine] || '';
    }

    getFormattedData(serializedJson) {
        try {
            const parsed = JSON.parse(serializedJson);
            // Set violationCounts from the top-level property
            this.violationCounts = parsed.violationCounts || null;
            const formattedJson = this.transformJson(parsed);

            if (formattedJson?.length) {
                return {
                    formattedJson,
                    type: 'Table'
                };
            } else {
                return {
                    formattedJson,
                    type: 'YAML'
                };
            }
        } catch (error) {
            return {
                formattedJson: serializedJson,
                type: 'String'
            };
        }
    }

    groupByEngineAndRule(violations) {
        // Your existing grouping logic
    }

    groupByEngineAndRuleArray(violations) {
        const engines = this.processViolationsByEngine(violations, this.selectedSeverity);
        return this.transformEngineObjectsToArray(engines, true);
    }

    groupByFilename(violations) {
        // New logic to group by filename
        const grouped = {};
        violations.forEach(violation => {
            const file = violation.sinkFileName || violation.file || UNKNOWN_FILE;
            if (!grouped[file]) {
                grouped[file] = [];
            }
            grouped[file].push(violation);
        });
        return grouped;
    }

    groupByFilenameArray(violations) {
        if (!violations) {
            return [];
        }

        const filterSeverity = this.selectedSeverity;
        const grouped = {};

        violations.forEach(violation => {
            if (filterSeverity && String(violation.severity) !== String(filterSeverity)) {
                return;
            }

            const file = violation.sinkFileName || violation.file || UNKNOWN_FILE;
            if (!grouped[file]) {
                grouped[file] = [];
            }
            grouped[file].push(violation);
        });

        return Object.keys(grouped).map(file => ({
            key: file,
            label: file,
            violations: grouped[file]
        }));
    }

    handleGroupByChange(event) {
        this.groupBy = event.detail.value;
    }

    handleSearch(event) {
        this.searchValue = event.target.value;
        const searchTerm = this.searchValue ? this.searchValue.trim().toLowerCase() : '';

        if (!searchTerm) {
            this._clearSearch();
        } else {
            this._applySearch(searchTerm);
        }
    }

    handleSeverityClick(event) {
        const severity = event.currentTarget.dataset.severity;
        this.selectedSeverity = (this.selectedSeverity === severity) ? null : severity;
    }

    handleClearFilters() {
        this.selectedSeverity = null;
        this.filteredJson = null;
        this.searchValue = '';
    }

    // Helper method to extract file path after 'default/'
    extractFileAfterDefault(filePath) {
        if (!filePath) {
            return UNKNOWN_FILE;
        }

        const match = filePath.match(MAIN_DEFAULT_PATTERN);
        if (match) {
            const [, metaType, fileKey] = match;
            return `${metaType}/${fileKey}`;
        }

        return filePath;
    }

    // Transformation function
    transformJson(parsedJson) {
        if (parsedJson.violations && Array.isArray(parsedJson.violations)) {
            return parsedJson.violations.map((violation, idx) => {
                const primaryLoc = violation.locations?.[violation.primaryLocationIndex] || violation.locations?.[0] || {};
                const fullFilePath = primaryLoc.file;

                // Extract file path after 'default/' for display
                const displayFilePath = this.extractFileAfterDefault(fullFilePath);

                return {
                    allLocations: violation.locations,
                    engine: violation.engine,
                    file: displayFilePath,
                    fullViolation: violation,
                    id: `${violation.rule}-${fullFilePath}-${primaryLoc.startLine}-${idx}`,
                    line: primaryLoc.startLine,
                    message: violation.message,
                    resource: violation.resources?.[0] || '',
                    rule: violation.rule,
                    severity: violation.severity,
                    tags: violation.tags,
                    severityLabel: `${violation.severity} (${SEVERITY_LABELS[violation.severity] || ''})`
                };
            });
        }
        return [];
    }

    _applySearch(searchTerm) {
        this.filteredJson = this.formattedJson.filter((row) => {
            for (const key in row) {
                const value = String(row[key]) || '';
                if (value && value.toLowerCase()?.includes(searchTerm)) {
                    return true;
                }
            }
            return false;
        });
    }

    _clearSearch() {
        this.filteredJson = null;
    }
}