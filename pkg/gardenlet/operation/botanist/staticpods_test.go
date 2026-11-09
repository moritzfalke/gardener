// SPDX-FileCopyrightText: Contributors to the Gardener project
//
// SPDX-License-Identifier: Apache-2.0

package botanist

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/utils/ptr"

	gardencorev1beta1 "github.com/gardener/gardener/pkg/apis/core/v1beta1"
	"github.com/gardener/gardener/pkg/gardenlet/operation"
	shootpkg "github.com/gardener/gardener/pkg/gardenlet/operation/shoot"
)

var _ = Describe("StaticPods", func() {
	Describe("#oscExtensionControllerAbsent", func() {
		var (
			b     *Botanist
			shoot *gardencorev1beta1.Shoot
		)

		BeforeEach(func() {
			shoot = &gardencorev1beta1.Shoot{}
			b = &Botanist{Operation: &operation.Operation{Shoot: &shootpkg.Shoot{}}}
			b.Shoot.SetInfo(shoot)
		})

		selfHosted := func() {
			shoot.Spec.Provider.Workers = []gardencorev1beta1.Worker{{ControlPlane: &gardencorev1beta1.WorkerControlPlane{}}}
			b.Shoot.SetInfo(shoot)
		}
		managedInfra := func() {
			shoot.Spec.SecretBindingName = ptr.To("my-secret-binding")
			b.Shoot.SetInfo(shoot)
		}

		It("should return true for a self-hosted shoot with unmanaged infrastructure", func() {
			selfHosted()
			Expect(b.oscExtensionControllerAbsent()).To(BeTrue())
		})

		It("should return false for a self-hosted shoot with managed infrastructure", func() {
			selfHosted()
			managedInfra()
			Expect(b.oscExtensionControllerAbsent()).To(BeFalse())
		})

		It("should return false for a non-self-hosted shoot", func() {
			Expect(b.oscExtensionControllerAbsent()).To(BeFalse())
		})
	})
})
