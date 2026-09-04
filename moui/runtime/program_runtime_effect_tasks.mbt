///|
fn[Msg] ProgramRuntimeDiagnostics::start_effect_task(
  self : ProgramRuntimeDiagnostics,
  descriptor : @core.EffectDescriptor,
  start : ((Msg) -> Unit) -> (() -> Unit)?,
  dispatch : (Msg) -> Unit,
) -> Unit {
  self.cancel_effect_tasks_replaced_by_descriptor(descriptor)
  let token = self.next_effect_task_value
  self.next_effect_task_value = self.next_effect_task_value + 1
  let active = Ref(true)
  let cancel : Ref[(() -> Unit)?] = Ref(None)
  self.active_effect_tasks.push({ token, descriptor, active, cancel })
  self.started_effect_task_count = self.started_effect_task_count + 1
  self.effect_task_lifecycle.push({
    key: descriptor.key(),
    kind: descriptor.kind(),
    label: descriptor.label(),
    status: EffectTaskLifecycleStatus::EffectTaskActive,
    cancel_reason: None,
  })
  let cleanup = start(message => {
    if active.val {
      active.val = false
      ignore(self.complete_effect_task(token))
      dispatch(message)
    } else {
      self.record_ignored_effect_task_dispatch()
    }
  })
  cancel.val = cleanup
  if cleanup is None && active.val {
    active.val = false
    ignore(self.complete_effect_task(token))
  }
}

///|
fn ProgramRuntimeDiagnostics::complete_effect_task(
  self : ProgramRuntimeDiagnostics,
  token : Int,
) -> Bool {
  let mut completed : ActiveProgramEffectTask? = None
  let remaining : Array[ActiveProgramEffectTask] = []
  for task in self.active_effect_tasks {
    match completed {
      None =>
        if task.token == token {
          completed = Some(task)
        } else {
          remaining.push(task)
        }
      Some(_) => remaining.push(task)
    }
  }
  self.active_effect_tasks = remaining
  match completed {
    Some(task) => {
      self.completed_effect_task_count = self.completed_effect_task_count + 1
      self.effect_task_lifecycle.push({
        key: task.descriptor.key(),
        kind: task.descriptor.kind(),
        label: task.descriptor.label(),
        status: EffectTaskLifecycleStatus::EffectTaskCompleted,
        cancel_reason: None,
      })
      true
    }
    None => false
  }
}

///|
fn ProgramRuntimeDiagnostics::cancel_effect_tasks_replaced_by_descriptor(
  self : ProgramRuntimeDiagnostics,
  descriptor : @core.EffectDescriptor,
) -> Unit {
  let remaining : Array[ActiveProgramEffectTask] = []
  for task in self.active_effect_tasks {
    if task.descriptor.key() == descriptor.key() {
      let reason = if task.descriptor.kind() == descriptor.kind() {
        EffectTaskCancelReason::EffectTaskKeyChanged
      } else {
        EffectTaskCancelReason::EffectTaskKindChanged
      }
      if task.descriptor.kind() != descriptor.kind() ||
        task.descriptor.label() != descriptor.label() {
        self.record_effect_task_key_supersession(task.descriptor, descriptor)
      }
      self.cancel_effect_task(task, reason)
    } else {
      remaining.push(task)
    }
  }
  self.active_effect_tasks = remaining
}

///|
fn ProgramRuntimeDiagnostics::cancel_all_effect_tasks(
  self : ProgramRuntimeDiagnostics,
  reason : EffectTaskCancelReason,
) -> Unit {
  for task in self.active_effect_tasks {
    self.cancel_effect_task(task, reason)
  }
  self.active_effect_tasks = []
}

///|
fn ProgramRuntimeDiagnostics::cancel_effect_task(
  self : ProgramRuntimeDiagnostics,
  task : ActiveProgramEffectTask,
  reason : EffectTaskCancelReason,
) -> Unit {
  task.active.val = false
  match task.cancel.val {
    Some(cancel) => cancel()
    None => ()
  }
  self.cancelled_effect_task_count = self.cancelled_effect_task_count + 1
  self.effect_task_lifecycle.push({
    key: task.descriptor.key(),
    kind: task.descriptor.kind(),
    label: task.descriptor.label(),
    status: EffectTaskLifecycleStatus::EffectTaskCancelled,
    cancel_reason: Some(reason),
  })
}
