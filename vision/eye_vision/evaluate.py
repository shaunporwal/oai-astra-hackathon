"""Evaluate capture usability against independent labels, with subject split checks."""
import argparse
import json
from pathlib import Path
import re

TASK = "capture_usability_v1"


def read_labels(path):
    rows = [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]
    if not rows:
        raise ValueError("Labels file is empty")
    cases, subjects, hashes = set(), {}, {}
    for row in rows:
        required = ("case_id", "subject_id", "source_sha256", "manifest_sha256", "split", "task", "label", "label_source", "reviewer_id", "device", "capture_type")
        if any(not isinstance(row.get(key), str) or not row[key].strip() for key in required):
            raise ValueError("Every label needs nonempty fields: " + ", ".join(required))
        if row["case_id"] in cases:
            raise ValueError("Duplicate case_id")
        cases.add(row["case_id"])
        if row["task"] != TASK or row["label"] not in ("usable", "unusable"):
            raise ValueError("Only independently labeled capture usability is supported")
        if row["label_source"] not in ("human_review", "expert_adjudicated"):
            raise ValueError("Model-generated labels are not evaluation ground truth")
        if row["split"] not in ("train", "dev", "test"):
            raise ValueError("Split must be train, dev, or test")
        for key in ("source_sha256", "manifest_sha256"):
            if not re.fullmatch(r"[0-9a-f]{64}", row[key]):
                raise ValueError(f"{key} must be a lowercase SHA256 digest")
        for field, mapping in (("subject_id", subjects), ("source_sha256", hashes)):
            value = row[field]
            if value in mapping and mapping[value] != row["split"]:
                raise ValueError(f"Split leakage detected for {field}")
            mapping[value] = row["split"]
    return rows


def evaluate(labels, predictions, split="test"):
    references = {row["case_id"]: row for row in labels if row["split"] == split}
    if not references:
        raise ValueError(f"No labels for split {split}")
    by_case = {}
    for row in predictions:
        case = row["case_id"]
        if case not in references or case in by_case:
            raise ValueError("Prediction is duplicated or not in the selected split")
        if row.get("task") != TASK or row.get("prediction") not in ("usable", "unusable", "abstain"):
            raise ValueError("Invalid prediction task or value")
        if row.get("source_sha256") != references[case]["source_sha256"]:
            raise ValueError("Prediction was produced from a different source video")
        if row.get("manifest_sha256") != references[case]["manifest_sha256"]:
            raise ValueError("Prediction used a different prepared frame set")
        by_case[case] = row["prediction"]
    matrix = {label: {pred: 0 for pred in ("usable", "unusable", "abstain", "missing")}
              for label in ("usable", "unusable")}
    for case, row in references.items():
        matrix[row["label"]][by_case.get(case, "missing")] += 1
    tp, fn = matrix["usable"]["usable"], matrix["usable"]["unusable"]
    tn, fp = matrix["unusable"]["unusable"], matrix["unusable"]["usable"]
    total = len(references)
    answered = tp + fn + tn + fp
    positive = sum(matrix["usable"].values())
    negative = sum(matrix["unusable"].values())
    ratio = lambda n, d: n / d if d else None
    return {
        "task": TASK, "split": split, "cases": total,
        "subjects": len({row["subject_id"] for row in references.values()}),
        "prediction_coverage": len(by_case) / total,
        "answer_coverage": answered / total,
        "abstentions": sum(row["abstain"] for row in matrix.values()),
        "missing_predictions": total - len(by_case),
        "confusion": matrix,
        "accuracy_answered": ratio(tp + tn, answered),
        "usable_recall_answered": ratio(tp, tp + fn),
        "unusable_recall_answered": ratio(tn, tn + fp),
        "usable_recall_all": ratio(tp, positive),
        "unusable_recall_all": ratio(tn, negative),
        "note": "Capture-quality agreement only; no clinical diagnostic performance is measured.",
    }


def main():
    parser = argparse.ArgumentParser(description="Validate labels or score capture usability; no model calls")
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--predictions", nargs="*", type=Path)
    parser.add_argument("--split", choices=("train", "dev", "test"), default="test")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        labels = read_labels(args.labels)
        if args.predictions is None:
            report = {"status": "valid", "cases": len(labels), "task": TASK}
        else:
            predictions = [json.loads(path.read_text()) for path in args.predictions]
            report = evaluate(labels, predictions, args.split)
        encoded = json.dumps(report, indent=2, allow_nan=False) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with args.output.open("x") as handle:
                handle.write(encoded)
        print(encoded, end="")
    except (ValueError, KeyError, TypeError, OSError) as exc:
        parser.exit(1, f"Evaluation failed: {exc}\n")


if __name__ == "__main__":
    main()
