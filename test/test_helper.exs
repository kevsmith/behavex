ExUnit.start()

Mox.defmock(Behavex.MockOperation, for: Behavex.Operation)
Mox.defmock(Behavex.HighPriorityOperation, for: Behavex.Operation)
Mox.defmock(Behavex.MediumPriorityOperation, for: Behavex.Operation)
Mox.defmock(Behavex.LowPriorityOperation, for: Behavex.Operation)
