<script setup lang="ts">
import { ref, onMounted } from "vue";
import { getCustomers, createCustomer, archiveCustomer } from "@/modules/customers/services/customer";
import type { Customer } from "@/types";
import { Users, Plus, X } from "lucide-vue-next";

const customers = ref<Customer[]>([]);
const showForm = ref(false);
const form = ref({
  name: "",
  phone: "",
  email: "",
  birthday: "",
});

async function load() {
  const r = await getCustomers();
  customers.value = r.data ?? [];
}

async function submit() {
  if (!form.value.name.trim()) return;
  await createCustomer({
    ...form.value,
    phone: form.value.phone || null,
    email: form.value.email || null,
    birthday: form.value.birthday || null,
  });
  showForm.value = false;
  form.value = { name: "", phone: "", email: "", birthday: "" };
  await load();
}

async function archive(id: string) {
  if (!confirm("Archive this customer?")) return;
  await archiveCustomer(id);
  await load();
}

function fmtCurrency(n: number) {
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", minimumFractionDigits: 0 }).format(n);
}

onMounted(load);
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-white">Customers</h2>
      <button
        class="flex items-center gap-1.5 rounded-lg bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500"
        @click="showForm = !showForm"
      >
        <Plus class="h-4 w-4" />
        Add
      </button>
    </div>

    <div v-if="showForm" class="rounded-xl border border-gray-700 bg-gray-800 p-4">
      <div class="mb-3 flex items-center justify-between">
        <h3 class="text-sm font-medium text-white">New Customer</h3>
        <button @click="showForm = false" class="text-gray-400 hover:text-white"><X class="h-4 w-4" /></button>
      </div>
      <form @submit.prevent="submit" class="grid grid-cols-2 gap-3">
        <input v-model="form.name" placeholder="Name *" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500" required />
        <input v-model="form.phone" placeholder="Phone" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500" />
        <input v-model="form.email" type="email" placeholder="Email" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500" />
        <input v-model="form.birthday" type="date" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <button type="submit" class="col-span-2 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-500">Save</button>
      </form>
    </div>

    <div class="rounded-xl border border-gray-700 bg-gray-800">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-700 text-left text-gray-400">
            <th class="p-3">Name</th>
            <th class="p-3">Phone</th>
            <th class="p-3">Email</th>
            <th class="p-3 text-right">Points</th>
            <th class="p-3 text-right">Spending</th>
            <th class="p-3"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in customers" :key="c.id" class="border-b border-gray-700/50 hover:bg-gray-700/30">
            <td class="p-3 text-white">{{ c.name }}</td>
            <td class="p-3 text-gray-400">{{ c.phone || "-" }}</td>
            <td class="p-3 text-gray-400">{{ c.email || "-" }}</td>
            <td class="p-3 text-right text-amber-400">{{ c.points }}</td>
            <td class="p-3 text-right text-gray-400">{{ fmtCurrency(c.total_spending) }}</td>
            <td class="p-3 text-right">
              <button @click="archive(c.id)" class="text-xs text-gray-500 hover:text-red-400">Archive</button>
            </td>
          </tr>
          <tr v-if="customers.length === 0">
            <td colspan="6" class="p-6 text-center text-gray-500">
              <Users class="mx-auto mb-2 h-8 w-8" />
              No customers yet
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
