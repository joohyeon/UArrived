"""Unit tests for the `sync_mailbox` serialization-conflict retry (see core/profile.jac).

A real SERIALIZABLE conflict needs two concurrent transactions racing on a live Postgres, which
a unit test can't set up. Instead these tests drive `retry_on_conflict` directly with a fake
callable that raises the same `PgWireError` shape the runtime raises for SQLSTATE 40001
("could not serialize access due to read/write dependencies among transactions... The
transaction might succeed if retried"), and a fake `sleep` so nothing actually waits."""

import from jaclang.data.pgwire { PgWireError }
import from core.profile { retry_on_conflict, is_serialization_conflict }

glob CONFLICT: dict[str, str] = {
         "C": "40001",
         "M": "could not serialize access due to read/write dependencies among transactions"
     };

test "is_serialization_conflict is true only for SQLSTATE 40001" {
    assert is_serialization_conflict(PgWireError(CONFLICT));
    assert not is_serialization_conflict(
        PgWireError({"C": "40P01", "M": "deadlock detected"})
    );
    assert not is_serialization_conflict(PgWireError("no fields at all"));
}

test "retry_on_conflict retries a conflict and returns the eventual success" {
    calls: list[int] = [];
    def flaky -> str {
        calls.append(1);
        if len(calls) < 3 {
            raise PgWireError(CONFLICT);
        }
        return "synced";
    }
    naps: list[float] = [];
    result = retry_on_conflict(flaky, 3, lambda (delay: float) { naps.append(delay); });
    assert result == "synced";
    assert len(calls) == 3;
    assert len(naps) == 2;
}

test "retry_on_conflict exhausts its attempts and re-raises the original error" {
    calls: list[int] = [];
    def always_conflicts -> str {
        calls.append(1);
        raise PgWireError(CONFLICT);
    }
    threw = False;
    try {
        retry_on_conflict(always_conflicts, 3, lambda (_delay: float) {});
    } except PgWireError {
        threw = True;
    }
    assert threw;
    assert len(calls) == 3;
}

test "retry_on_conflict never retries an unrelated database error" {
    calls: list[int] = [];
    def other_error -> str {
        calls.append(1);
        raise PgWireError({"C": "40P01", "M": "deadlock detected"});
    }
    threw = False;
    try {
        retry_on_conflict(other_error, 3, lambda (_delay: float) {});
    } except PgWireError {
        threw = True;
    }
    assert threw;
    assert len(calls) == 1;
}
