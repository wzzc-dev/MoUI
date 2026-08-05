///|
test "frame coordinator keeps queued frames pending until completion" {
  let redraws = Ref(0)
  let presents = Ref(0)
  let coordinator = FrameCoordinator::new(
    hooks=WindowFrameHooks::new(
      finish_presented=presented => if presented { presents.val += 1 },
      request_redraw=() => redraws.val += 1,
    ),
  )
  assert_true(coordinator.prepare_frame())
  assert_true(!coordinator.finish_presented(true, false, false))
  assert_true(coordinator.pending())
  assert_true(coordinator.presented_count() == 0)
  assert_true(redraws.val == 1)
  assert_true(!coordinator.prepare_frame())
  assert_true(coordinator.finish_presented(false, true, true))
  assert_true(!coordinator.pending())
  assert_true(presents.val == 1)
  assert_true(coordinator.presented_count() == 1)
}
